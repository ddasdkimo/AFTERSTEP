import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/constants.dart';
import '../../core/utils/geo_utils.dart';
import '../../data/models/location_point.dart';
import '../../data/models/unlock_point.dart';

/// Fog 管理器
///
/// 負責管理 Fog 解鎖狀態，處理位置更新和停留事件。
class FogManager {
  /// 建立 Fog 管理器
  FogManager({
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  /// Fog 狀態
  FogState _state = FogState.empty;

  /// 當前軌跡
  UnlockPath? _currentPath;

  /// 同步計時器
  Timer? _syncTimer;

  /// 同步回調
  Future<void> Function(List<UnlockPoint> points, List<UnlockPath> paths)?
      _syncCallback;

  /// Fog 更新串流
  final _fogUpdatedController = BehaviorSubject<FogState>();

  /// 新區域解鎖串流
  final _newAreaUnlockedController = BehaviorSubject<double>();

  /// Fog 更新串流
  Stream<FogState> get fogUpdated => _fogUpdatedController.stream;

  /// 新區域解鎖串流
  Stream<double> get newAreaUnlocked => _newAreaUnlockedController.stream;

  /// 當前 Fog 狀態
  FogState get state => _state;

  /// 所有解鎖點
  List<UnlockPoint> get points => _state.points;

  /// 所有解鎖軌跡
  List<UnlockPath> get paths => _state.paths;

  /// 設定同步回調
  void setSyncCallback(
    Future<void> Function(List<UnlockPoint> points, List<UnlockPath> paths)
        callback,
  ) {
    _syncCallback = callback;
  }

  /// 初始化狀態
  void initialize(FogState initialState) {
    _state = initialState;
    _fogUpdatedController.add(_state);
  }

  /// 處理有效位置
  void processValidLocation(ProcessedLocation location) {
    final lat = location.point.latitude;
    final lng = location.point.longitude;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 檢查是否需要合併（與現有點太近）
    if (_shouldMergePoint(lat, lng)) {
      _updateCurrentPath(lat, lng);
      return;
    }

    // 建立新解鎖點
    final point = UnlockPoint(
      id: _uuid.v4(),
      latitude: lat,
      longitude: lng,
      radius: FogConfig.unlockRadiusInstant,
      timestamp: now,
      type: UnlockType.walk,
    );

    // 加入狀態
    final newPoints = List<UnlockPoint>.from(_state.points)..add(point);

    // 限制點數量
    if (newPoints.length > FogConfig.maxPointsInMemory) {
      newPoints.removeAt(0);
    }

    _state = _state.copyWith(points: newPoints);

    // 更新軌跡
    _updateCurrentPath(lat, lng);

    // 發出更新
    _fogUpdatedController.add(_state);

    // 排程同步
    _scheduleSync();
  }

  /// 處理停留事件
  void processStayEvent(StayEvent stay) {
    if (stay.duration < GpsConfig.stayMinDuration) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    // 尋找附近的現有點
    final existingPoint = _findNearbyPoint(
      stay.centerLat,
      stay.centerLng,
      20, // 20 公尺內
    );

    if (existingPoint != null) {
      // 擴展現有點的半徑
      final newRadius = FogConfig.unlockRadiusStay
          .clamp(existingPoint.radius, FogConfig.unlockRadiusStay);

      if (newRadius > existingPoint.radius) {
        final updatedPoint = existingPoint.copyWith(radius: newRadius);
        final newPoints = _state.points.map((p) {
          return p.id == existingPoint.id ? updatedPoint : p;
        }).toList();

        _state = _state.copyWith(points: newPoints);
        _fogUpdatedController.add(_state);
        _scheduleSync();
      }
    } else {
      // 建立新的停留解鎖點
      final point = UnlockPoint(
        id: _uuid.v4(),
        latitude: stay.centerLat,
        longitude: stay.centerLng,
        radius: FogConfig.unlockRadiusStay,
        timestamp: now,
        type: UnlockType.stay,
      );

      final newPoints = List<UnlockPoint>.from(_state.points)..add(point);
      _state = _state.copyWith(points: newPoints);
      _fogUpdatedController.add(_state);
      _scheduleSync();
    }
  }

  /// 檢查是否應該合併點
  bool _shouldMergePoint(double lat, double lng) {
    return _findNearbyPoint(lat, lng, FogConfig.pointMergeDistance) != null;
  }

  /// 尋找附近的點
  UnlockPoint? _findNearbyPoint(double lat, double lng, double maxDist) {
    for (final point in _state.points) {
      final dist = GeoUtils.haversineDistance(
        lat,
        lng,
        point.latitude,
        point.longitude,
      );
      if (dist <= maxDist) return point;
    }
    return null;
  }

  /// 更新當前軌跡
  void _updateCurrentPath(double lat, double lng) {
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_currentPath == null) {
      // 開始新軌跡
      _currentPath = UnlockPath(
        id: _uuid.v4(),
        points: [(lat: lat, lng: lng)],
        width: FogConfig.unlockRadiusInstant * 2,
        timestamp: now,
      );
    } else {
      // 加入新點
      final newPoints = List<({double lat, double lng})>.from(_currentPath!.points)
        ..add((lat: lat, lng: lng));

      _currentPath = _currentPath!.copyWith(
        points: newPoints,
        timestamp: now,
      );
    }

    // 更新軌跡到狀態
    _updatePathInState();
  }

  /// 更新軌跡到狀態
  void _updatePathInState() {
    if (_currentPath == null) return;

    final pathIndex =
        _state.paths.indexWhere((p) => p.id == _currentPath!.id);

    List<UnlockPath> newPaths;
    if (pathIndex >= 0) {
      newPaths = List<UnlockPath>.from(_state.paths);
      newPaths[pathIndex] = _currentPath!;
    } else {
      newPaths = List<UnlockPath>.from(_state.paths)..add(_currentPath!);
    }

    _state = _state.copyWith(paths: newPaths);
  }

  /// 結束當前軌跡
  void endCurrentPath() {
    if (_currentPath != null) {
      _updatePathInState();
      _currentPath = null;
      _scheduleSync();
    }
  }

  /// 排程同步
  void _scheduleSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(
      Duration(milliseconds: FogConfig.syncDebounce),
      _performSync,
    );
  }

  /// 執行同步
  Future<void> _performSync() async {
    if (_syncCallback == null) return;

    // 取得未同步的資料
    final unsyncedPoints =
        _state.points.where((p) => !p.synced).toList();
    final unsyncedPaths =
        _state.paths.where((p) => !p.synced).toList();

    if (unsyncedPoints.isEmpty && unsyncedPaths.isEmpty) return;

    try {
      await _syncCallback!(unsyncedPoints, unsyncedPaths);

      // 標記為已同步
      final syncedPoints = _state.points.map((p) {
        if (!p.synced) {
          return p.copyWith(synced: true);
        }
        return p;
      }).toList();

      final syncedPaths = _state.paths.map((p) {
        if (!p.synced) {
          return p.copyWith(synced: true);
        }
        return p;
      }).toList();

      _state = _state.copyWith(
        points: syncedPoints,
        paths: syncedPaths,
        lastSyncTime: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      // 同步失敗，下次再試
    }
  }

  /// 強制同步
  Future<void> forceSync() async {
    _syncTimer?.cancel();
    await _performSync();
  }

  /// 取得視口內的解鎖點
  List<UnlockPoint> getPointsInViewport(
    double north,
    double south,
    double east,
    double west,
  ) {
    return _state.points.where((p) {
      return p.latitude >= south &&
          p.latitude <= north &&
          p.longitude >= west &&
          p.longitude <= east;
    }).toList();
  }

  /// 取得視口內的解鎖軌跡
  List<UnlockPath> getPathsInViewport(
    double north,
    double south,
    double east,
    double west,
  ) {
    return _state.paths.where((path) {
      return path.points.any((p) {
        return p.lat >= south &&
            p.lat <= north &&
            p.lng >= west &&
            p.lng <= east;
      });
    }).toList();
  }

  /// 釋放資源
  void dispose() {
    _syncTimer?.cancel();
    _fogUpdatedController.close();
    _newAreaUnlockedController.close();
  }

  /// 重置狀態
  void reset() {
    _syncTimer?.cancel();
    _state = FogState.empty;
    _currentPath = null;
    _fogUpdatedController.add(_state);
  }
}
