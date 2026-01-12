import 'package:equatable/equatable.dart';

/// 移動狀態枚舉
enum MovementState {
  /// 靜止/漂移
  stationary,

  /// 有效步行
  walking,

  /// 快走（效率遞減）
  fastWalking,

  /// 騎車/開車（無效）
  tooFast,
}

/// 原始定位點
///
/// 表示從 GPS 獲取的單一定位資料。
class LocationPoint extends Equatable {
  /// 建立定位點
  const LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.altitude,
    this.speed,
  });

  /// 緯度
  final double latitude;

  /// 經度
  final double longitude;

  /// 精度 (公尺)
  final double accuracy;

  /// 時間戳記 (毫秒)
  final int timestamp;

  /// 海拔 (公尺，可選)
  final double? altitude;

  /// 系統回報速度 m/s (不可信，僅參考)
  final double? speed;

  @override
  List<Object?> get props => [
        latitude,
        longitude,
        accuracy,
        timestamp,
        altitude,
        speed,
      ];

  /// 從 Map 建立
  factory LocationPoint.fromMap(Map<String, dynamic> map) {
    return LocationPoint(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num).toDouble(),
      timestamp: map['timestamp'] as int,
      altitude: map['altitude'] != null
          ? (map['altitude'] as num).toDouble()
          : null,
      speed:
          map['speed'] != null ? (map['speed'] as num).toDouble() : null,
    );
  }

  /// 轉換為 Map
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp,
      'altitude': altitude,
      'speed': speed,
    };
  }

  /// 複製並修改
  LocationPoint copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    int? timestamp,
    double? altitude,
    double? speed,
  }) {
    return LocationPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
    );
  }
}

/// 處理後位置
///
/// 包含原始定位點和計算後的額外資訊。
class ProcessedLocation extends Equatable {
  /// 建立處理後位置
  const ProcessedLocation({
    required this.point,
    required this.calculatedSpeed,
    required this.movementState,
    required this.isValid,
    required this.distanceFromLast,
  });

  /// 原始定位點
  final LocationPoint point;

  /// 自行計算的速度 (m/s)
  final double calculatedSpeed;

  /// 移動狀態
  final MovementState movementState;

  /// 是否用於 Fog 解鎖
  final bool isValid;

  /// 與上一點距離 (公尺)
  final double distanceFromLast;

  @override
  List<Object?> get props => [
        point,
        calculatedSpeed,
        movementState,
        isValid,
        distanceFromLast,
      ];

  /// 複製並修改
  ProcessedLocation copyWith({
    LocationPoint? point,
    double? calculatedSpeed,
    MovementState? movementState,
    bool? isValid,
    double? distanceFromLast,
  }) {
    return ProcessedLocation(
      point: point ?? this.point,
      calculatedSpeed: calculatedSpeed ?? this.calculatedSpeed,
      movementState: movementState ?? this.movementState,
      isValid: isValid ?? this.isValid,
      distanceFromLast: distanceFromLast ?? this.distanceFromLast,
    );
  }
}

/// 停留事件
///
/// 表示使用者在某處停留的事件。
class StayEvent extends Equatable {
  /// 建立停留事件
  const StayEvent({
    required this.centerLat,
    required this.centerLng,
    required this.startTime,
    required this.duration,
    required this.radius,
  });

  /// 中心緯度
  final double centerLat;

  /// 中心經度
  final double centerLng;

  /// 開始時間 (毫秒)
  final int startTime;

  /// 停留時長 (秒)
  final int duration;

  /// 停留範圍半徑 (公尺)
  final double radius;

  @override
  List<Object?> get props => [
        centerLat,
        centerLng,
        startTime,
        duration,
        radius,
      ];

  /// 複製並修改
  StayEvent copyWith({
    double? centerLat,
    double? centerLng,
    int? startTime,
    int? duration,
    double? radius,
  }) {
    return StayEvent(
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      radius: radius ?? this.radius,
    );
  }
}
