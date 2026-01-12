import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/config/constants.dart';
import '../../core/utils/geo_utils.dart';
import '../../data/models/location_point.dart';
import 'drift_filter.dart';
import 'speed_calculator.dart';
import 'stay_detector.dart';

/// 位置服務
///
/// 負責追蹤使用者位置、計算速度、過濾漂移、偵測停留。
class LocationService {
  /// 建立位置服務
  LocationService({
    SpeedCalculator? speedCalculator,
    DriftFilter? driftFilter,
    StayDetector? stayDetector,
  })  : _speedCalculator = speedCalculator ?? SpeedCalculator(),
        _driftFilter = driftFilter ?? DriftFilter(),
        _stayDetector = stayDetector ?? StayDetector();

  final SpeedCalculator _speedCalculator;
  final DriftFilter _driftFilter;
  final StayDetector _stayDetector;

  LocationPoint? _lastPoint;
  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;
  bool _isInForeground = true;

  /// 有效位置串流
  final _validLocationsController = BehaviorSubject<ProcessedLocation>();

  /// 停留事件串流
  final _stayEventsController = BehaviorSubject<StayEvent>();

  /// 原始位置串流 (用於除錯)
  final _rawLocationsController = BehaviorSubject<LocationPoint>();

  /// 有效位置串流
  Stream<ProcessedLocation> get validLocations =>
      _validLocationsController.stream;

  /// 停留事件串流
  Stream<StayEvent> get stayEvents => _stayEventsController.stream;

  /// 原始位置串流
  Stream<LocationPoint> get rawLocations => _rawLocationsController.stream;

  /// 最後有效位置
  ProcessedLocation? get lastValidLocation =>
      _validLocationsController.valueOrNull;

  /// 最後原始位置
  LocationPoint? get lastRawLocation => _lastPoint;

  /// 是否正在追蹤
  bool get isTracking => _isTracking;

  /// 檢查位置權限
  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// 請求位置權限
  Future<bool> requestPermission() async {
    final permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// 開始追蹤
  Future<void> startTracking() async {
    if (_isTracking) return;

    final hasPermission = await checkPermission();
    if (!hasPermission) {
      throw Exception('Location permission not granted');
    }

    _isTracking = true;

    final settings = _createLocationSettings();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      _handlePosition,
      onError: _handleError,
    );
  }

  /// 停止追蹤
  void stopTracking() {
    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// 設定前景/背景模式
  void setForeground(bool isForeground) {
    if (_isInForeground == isForeground) return;
    _isInForeground = isForeground;

    // 重新建立串流以更新取樣間隔
    if (_isTracking) {
      stopTracking();
      startTracking();
    }
  }

  /// 處理原始 GPS 位置
  void _handlePosition(Position position) {
    final point = LocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp.millisecondsSinceEpoch,
      altitude: position.altitude,
      speed: position.speed,
    );

    processRawLocation(point);
  }

  /// 處理原始位置（可用於測試注入）
  void processRawLocation(LocationPoint raw) {
    // 發出原始位置
    _rawLocationsController.add(raw);

    // 1. 精度過濾
    if (raw.accuracy > GpsConfig.accuracyThreshold) {
      return;
    }

    // 2. 計算速度和距離
    double speed = 0;
    double distance = 0;

    if (_lastPoint != null) {
      distance = GeoUtils.haversineDistance(
        _lastPoint!.latitude,
        _lastPoint!.longitude,
        raw.latitude,
        raw.longitude,
      );
      speed = _speedCalculator.calculate(raw, _lastPoint!);
    }

    // 3. 判定移動狀態
    final state = determineMovementState(speed);

    // 4. 漂移過濾
    final isValid = _driftFilter.process(raw, state);

    // 5. 停留偵測
    final completedStay = _stayDetector.process(raw);
    if (completedStay != null) {
      _stayEventsController.add(completedStay);
    }

    // 6. 輸出處理後位置
    final processed = ProcessedLocation(
      point: raw,
      calculatedSpeed: speed,
      movementState: state,
      isValid: isValid && state != MovementState.tooFast,
      distanceFromLast: distance,
    );

    if (processed.isValid) {
      _validLocationsController.add(processed);
    }

    _lastPoint = raw;
  }

  /// 處理錯誤
  void _handleError(Object error) {
    // 錯誤處理 - 可以加入日誌或通知
  }

  /// 建立位置設定
  LocationSettings _createLocationSettings() {
    final interval = _isInForeground
        ? GpsConfig.intervalForeground
        : GpsConfig.intervalBackground;

    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, // 接收所有更新，由我們自己過濾
      timeLimit: Duration(milliseconds: interval),
    );
  }

  /// 取得當前位置（一次性）
  Future<LocationPoint?> getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      return LocationPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp.millisecondsSinceEpoch,
        altitude: position.altitude,
        speed: position.speed,
      );
    } catch (e) {
      return null;
    }
  }

  /// 釋放資源
  void dispose() {
    stopTracking();
    _validLocationsController.close();
    _stayEventsController.close();
    _rawLocationsController.close();
  }

  /// 重置所有內部狀態
  void reset() {
    _speedCalculator.reset();
    _driftFilter.reset();
    _stayDetector.reset();
    _lastPoint = null;
  }
}
