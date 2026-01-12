import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../../data/models/cell.dart';
import '../../data/models/location_point.dart';
import 'cell_cache.dart';
import 'geo_encoder.dart';

/// Cell 服務
///
/// 負責追蹤使用者當前所在的 Cell，管理 Cell 解鎖狀態。
class CellService {
  /// 建立 Cell 服務
  CellService({
    GeoEncoder? geoEncoder,
    CellQueryService? queryService,
    CellCache? cache,
  })  : _geoEncoder = geoEncoder ?? GeoEncoder(),
        _queryService = queryService ?? CellQueryService(),
        _cache = cache ?? CellCache();

  final GeoEncoder _geoEncoder;
  final CellQueryService _queryService;
  final CellCache _cache;

  Cell? _currentCell;
  String? _userId;

  /// 活動記錄節流 Map<cellId, lastRecordTime>
  final Map<String, int> _lastActivityRecord = {};

  /// 活動記錄節流時間 (毫秒)
  static const int _activityRecordThrottle = 60000;

  /// Cell 變更串流
  final _cellChangedController = BehaviorSubject<Cell>();

  /// Cell 解鎖串流
  final _cellUnlockedController = BehaviorSubject<Cell>();

  /// Cell 變更串流
  Stream<Cell> get cellChanged => _cellChangedController.stream;

  /// Cell 解鎖串流
  Stream<Cell> get cellUnlocked => _cellUnlockedController.stream;

  /// 當前 Cell
  Cell? get currentCell => _currentCell;

  /// 已解鎖的 Cell ID 集合
  final Set<String> _unlockedCellIds = {};

  /// 取得已解鎖的 Cell ID 集合
  Set<String> get unlockedCellIds => Set.unmodifiable(_unlockedCellIds);

  /// 初始化服務
  ///
  /// [userId] - 使用者 ID
  /// [unlockedCells] - 初始已解鎖 Cell 列表
  void initialize(String userId, {List<UserCellState>? unlockedCells}) {
    _userId = userId;

    if (unlockedCells != null) {
      for (final state in unlockedCells) {
        if (state.unlocked) {
          _unlockedCellIds.add(state.cellId);
          _cache.set(state.cellId, state);
        }
      }
    }
  }

  /// 處理位置更新
  ///
  /// [location] - 處理後的位置
  /// [onRecordActivity] - 記錄活動的回調（用於寫入 Firestore）
  /// [onUnlockCell] - 解鎖 Cell 的回調（用於寫入 Firestore）
  Future<void> processLocation(
    ProcessedLocation location, {
    Future<void> Function(String cellId)? onRecordActivity,
    Future<void> Function(String cellId)? onUnlockCell,
  }) async {
    final point = location.point;
    final cell = _geoEncoder.coordToCell(point.latitude, point.longitude);

    // Cell 變更檢測
    if (_currentCell?.cellId != cell.cellId) {
      _currentCell = cell;
      _cellChangedController.add(cell);

      // 預載入周圍 Cell 狀態
      final nearby = _queryService.getNearbyCells(
        point.latitude,
        point.longitude,
      );
      _preloadCellStates(nearby);
    }

    // 節流記錄活動
    if (onRecordActivity != null) {
      await _throttledRecordActivity(cell.cellId, onRecordActivity);
    }

    // 檢查並解鎖
    if (location.isValid && onUnlockCell != null) {
      await _checkAndUnlock(cell, onUnlockCell);
    }
  }

  /// 節流記錄活動
  Future<void> _throttledRecordActivity(
    String cellId,
    Future<void> Function(String cellId) onRecordActivity,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastActivityRecord[cellId] ?? 0;

    if (now - last > _activityRecordThrottle) {
      _lastActivityRecord[cellId] = now;
      await onRecordActivity(cellId);
    }
  }

  /// 檢查並解鎖 Cell
  Future<void> _checkAndUnlock(
    Cell cell,
    Future<void> Function(String cellId) onUnlockCell,
  ) async {
    // 檢查是否已解鎖
    if (_unlockedCellIds.contains(cell.cellId)) {
      return;
    }

    final cached = _cache.get(cell.cellId);
    if (cached?.unlocked == true) {
      _unlockedCellIds.add(cell.cellId);
      return;
    }

    // 解鎖
    await onUnlockCell(cell.cellId);

    final now = DateTime.now().millisecondsSinceEpoch;
    final newState = UserCellState(
      cellId: cell.cellId,
      unlocked: true,
      unlockedAt: now,
      lastVisit: now,
    );

    _cache.set(cell.cellId, newState);
    _unlockedCellIds.add(cell.cellId);
    _cellUnlockedController.add(cell);
  }

  /// 預載入 Cell 狀態
  void _preloadCellStates(List<Cell> cells) {
    // 將未快取的 Cell 加入快取（預設為未解鎖）
    for (final cell in cells) {
      if (!_cache.contains(cell.cellId)) {
        // 檢查是否在已解鎖集合中
        if (_unlockedCellIds.contains(cell.cellId)) {
          _cache.set(
            cell.cellId,
            UserCellState(
              cellId: cell.cellId,
              unlocked: true,
            ),
          );
        }
      }
    }
  }

  /// 取得指定 Cell 的狀態
  UserCellState? getCellState(String cellId) {
    return _cache.get(cellId);
  }

  /// 檢查 Cell 是否已解鎖
  bool isCellUnlocked(String cellId) {
    return _unlockedCellIds.contains(cellId);
  }

  /// 取得視口內的 Cell ID 列表
  List<String> getCellIdsInViewport(
    double north,
    double south,
    double east,
    double west,
  ) {
    return _queryService.getCellIdsInBounds(north, south, east, west);
  }

  /// 取得視口內已解鎖的 Cell ID 列表
  List<String> getUnlockedCellIdsInViewport(
    double north,
    double south,
    double east,
    double west,
  ) {
    final allIds = getCellIdsInViewport(north, south, east, west);
    return allIds.where((id) => _unlockedCellIds.contains(id)).toList();
  }

  /// 手動標記 Cell 為已解鎖（用於從資料庫載入）
  void markCellUnlocked(String cellId, {int? unlockedAt}) {
    _unlockedCellIds.add(cellId);
    _cache.set(
      cellId,
      UserCellState(
        cellId: cellId,
        unlocked: true,
        unlockedAt: unlockedAt,
      ),
    );
  }

  /// 批次標記 Cell 為已解鎖
  void markCellsUnlocked(List<String> cellIds) {
    for (final cellId in cellIds) {
      markCellUnlocked(cellId);
    }
  }

  /// 清空快取
  void clearCache() {
    _cache.clear();
  }

  /// 釋放資源
  void dispose() {
    _cellChangedController.close();
    _cellUnlockedController.close();
  }

  /// 重置服務
  void reset() {
    _currentCell = null;
    _userId = null;
    _lastActivityRecord.clear();
    _unlockedCellIds.clear();
    _cache.clear();
  }
}
