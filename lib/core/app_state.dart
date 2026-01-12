import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/location_point.dart';
import '../data/models/micro_event.dart';
import '../data/models/red_dot.dart';
import '../data/models/unlock_point.dart';
import '../features/cell/cell_service.dart';
import '../features/fog/fog_manager.dart';
import '../features/location/location_service.dart';
import '../features/micro_event/micro_event_service.dart';
import '../features/push/push_service.dart';
import '../features/red_dot/red_dot_service.dart';
import 'services/firebase_service.dart';
import 'services/storage_service.dart';

/// 應用程式狀態
///
/// 整合所有服務模組，提供統一的狀態管理。
class AppState extends ChangeNotifier {
  AppState({
    LocationService? locationService,
    CellService? cellService,
    FogManager? fogManager,
    RedDotService? redDotService,
    MicroEventService? microEventService,
    PushService? pushService,
    StorageService? storageService,
    FirebaseService? firebaseService,
  })  : _locationService = locationService ?? LocationService(),
        _cellService = cellService ?? CellService(),
        _fogManager = fogManager ?? FogManager(),
        _redDotService = redDotService ?? RedDotService(),
        _microEventService = microEventService ?? MicroEventService(),
        _pushService = pushService ?? PushService(),
        _storageService = storageService ?? StorageService(),
        _firebaseService = firebaseService ?? FirebaseService();

  final LocationService _locationService;
  final CellService _cellService;
  final FogManager _fogManager;
  final RedDotService _redDotService;
  final MicroEventService _microEventService;
  final PushService _pushService;
  final StorageService _storageService;
  final FirebaseService _firebaseService;

  final List<StreamSubscription> _subscriptions = [];

  // ==================== 狀態 ====================

  bool _isInitialized = false;
  bool _isTracking = false;
  ProcessedLocation? _currentLocation;
  FogState _fogState = FogState.empty;
  List<RedDot> _visibleRedDots = [];
  ViewportBounds? _viewport;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 是否正在追蹤
  bool get isTracking => _isTracking;

  /// 當前位置
  ProcessedLocation? get currentLocation => _currentLocation;

  /// Fog 狀態
  FogState get fogState => _fogState;

  /// 可見紅點
  List<RedDot> get visibleRedDots => _visibleRedDots;

  /// 微事件串流
  Stream<DisplayEvent> get microEventStream => _microEventService.eventTriggered;

  /// 當前使用者 ID
  String? get userId => _firebaseService.userId;

  // ==================== 初始化 ====================

  /// 初始化所有服務
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 初始化儲存
    await _storageService.initialize();

    // 初始化 Firebase
    await _firebaseService.initialize();

    // 匿名登入
    if (!_firebaseService.isSignedIn) {
      await _firebaseService.signInAnonymously();
    }

    // 初始化 Cell 服務
    if (_firebaseService.userId != null) {
      final unlockedCells = await _storageService.loadUnlockedCells();
      _cellService.initialize(_firebaseService.userId!, unlockedCells: unlockedCells);
    }

    // 從本地載入 Fog 狀態
    _fogState = await _storageService.loadFogState();
    _fogManager.initialize(_fogState);

    // 嘗試從 Firebase 載入更完整的資料
    if (_firebaseService.isSignedIn) {
      final cloudState = await _firebaseService.loadFogData();
      if (cloudState.points.length > _fogState.points.length) {
        _fogState = cloudState;
        _fogManager.initialize(_fogState);
        await _storageService.saveFogState(_fogState);
      }
    }

    // 設定 Fog 同步回調
    _fogManager.setSyncCallback((points, paths) async {
      await _firebaseService.syncFogData(points, paths);
    });

    // 初始化推播服務
    await _pushService.initialize();

    // 初始化微事件服務
    await _microEventService.initialize();

    // 設定紅點查詢回調
    _redDotService.setFetchActivitiesCallback((cellIds) async {
      return await _firebaseService.getCellActivities(cellIds);
    });

    // 設定微事件的紅點查詢回調
    _microEventService.setGetRedDotCallback((cellId) {
      return _redDotService.getRedDotForCell(cellId);
    });

    // 設定訂閱
    _setupSubscriptions();

    _isInitialized = true;
    notifyListeners();
  }

  /// 設定資料流訂閱
  void _setupSubscriptions() {
    // 監聽有效位置更新
    _subscriptions.add(
      _locationService.validLocations.listen(_onLocationUpdate),
    );

    // 監聽停留事件
    _subscriptions.add(
      _locationService.stayEvents.listen(_onStayEvent),
    );

    // 監聯 Fog 變更
    _subscriptions.add(
      _fogManager.fogUpdated.listen(_onFogStateChange),
    );

    // 監聽 Cell 解鎖
    _subscriptions.add(
      _cellService.cellUnlocked.listen(_onCellUnlocked),
    );

    // 監聽 Cell 變更（用於微事件）
    _subscriptions.add(
      _cellService.cellChanged.listen(_onCellChanged),
    );
  }

  // ==================== 位置追蹤 ====================

  /// 開始位置追蹤
  Future<bool> startTracking() async {
    if (_isTracking) return true;

    try {
      await _locationService.startTracking();
      _isTracking = true;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 停止位置追蹤
  void stopTracking() {
    _locationService.stopTracking();
    _isTracking = false;
    notifyListeners();
  }

  // ==================== 視窗管理 ====================

  /// 更新視窗範圍
  void updateViewport(ViewportBounds bounds) {
    _viewport = bounds;
    _updateVisibleRedDots();
  }

  // ==================== 事件處理 ====================

  /// 處理位置更新
  void _onLocationUpdate(ProcessedLocation location) {
    _currentLocation = location;

    // 處理 Cell 位置
    _cellService.processLocation(
      location,
      onRecordActivity: (cellId) async {
        await _firebaseService.recordCellActivity(cellId);
      },
      onUnlockCell: (cellId) async {
        await _firebaseService.unlockCell(cellId);
        await _storageService.saveCellState(
          _cellService.getCellState(cellId)!,
        );
      },
    );

    // 只有步行狀態才更新 Fog
    if (location.movementState == MovementState.walking ||
        location.movementState == MovementState.fastWalking) {
      _fogManager.processValidLocation(location);
    }

    notifyListeners();
  }

  /// 處理停留事件
  void _onStayEvent(StayEvent event) {
    // 更新 Fog（停留擴散）
    _fogManager.processStayEvent(event);
  }

  /// 處理 Cell 解鎖
  void _onCellUnlocked(dynamic cell) {
    // 觸發推播
    _pushService.handleCellUnlocked(cell.cellId as String);
  }

  /// 處理 Cell 變更
  void _onCellChanged(dynamic cell) {
    // 通知微事件服務
    _microEventService.onCellChanged(cell);
  }

  /// 處理 Fog 狀態變更
  void _onFogStateChange(FogState state) {
    _fogState = state;

    // 儲存到本地
    _storageService.saveFogState(state);

    _updateVisibleRedDots();
    notifyListeners();
  }

  /// 更新可見紅點
  Future<void> _updateVisibleRedDots() async {
    if (_viewport == null) {
      _visibleRedDots = [];
      return;
    }

    // 取得已解鎖的 Cell ID
    final unlockedCellIds = _cellService.unlockedCellIds;

    // 取得紅點
    _visibleRedDots = await _redDotService.getRedDotsInViewport(
      _viewport!,
      unlockedCellIds,
    );

    notifyListeners();
  }

  // ==================== 清理 ====================

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    _locationService.dispose();
    _cellService.dispose();
    _fogManager.dispose();
    _redDotService.dispose();
    _microEventService.dispose();
    _storageService.close();

    super.dispose();
  }
}
