import 'dart:collection';

import '../../core/config/constants.dart';
import '../../core/utils/geo_utils.dart';
import '../../data/models/location_point.dart';

/// 速度計算器
///
/// 負責計算使用者的移動速度，使用移動平均來過濾雜訊。
class SpeedCalculator {
  /// 建立速度計算器
  SpeedCalculator({
    int bufferSize = GpsConfig.speedBufferSize,
  }) : _bufferSize = bufferSize;

  final int _bufferSize;
  final Queue<double> _speedBuffer = Queue<double>();

  /// 計算當前速度
  ///
  /// [current] - 當前位置點
  /// [previous] - 上一個位置點
  /// 返回平滑後的速度 (m/s)
  double calculate(LocationPoint current, LocationPoint previous) {
    final distance = GeoUtils.haversineDistance(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );

    final timeDelta = (current.timestamp - previous.timestamp) / 1000.0;

    if (timeDelta <= 0) return 0;

    final instantSpeed = distance / timeDelta;

    // 加入緩衝區
    _speedBuffer.addLast(instantSpeed);
    if (_speedBuffer.length > _bufferSize) {
      _speedBuffer.removeFirst();
    }

    return _getSmoothedSpeed();
  }

  /// 取得平滑後的速度 (移動平均)
  double _getSmoothedSpeed() {
    if (_speedBuffer.isEmpty) return 0;

    final sum = _speedBuffer.reduce((a, b) => a + b);
    return sum / _speedBuffer.length;
  }

  /// 取得最新的原始速度
  double get lastInstantSpeed =>
      _speedBuffer.isNotEmpty ? _speedBuffer.last : 0;

  /// 重置計算器
  void reset() {
    _speedBuffer.clear();
  }
}

/// 判定移動狀態
///
/// [speed] - 速度 (m/s)
/// 返回移動狀態枚舉
MovementState determineMovementState(double speed) {
  if (speed < GpsConfig.speedMin) {
    return MovementState.stationary;
  }
  if (speed <= GpsConfig.speedMax) {
    return MovementState.walking;
  }
  if (speed <= GpsConfig.speedCutoff) {
    return MovementState.fastWalking;
  }
  return MovementState.tooFast;
}

/// 計算解鎖效率
///
/// [state] - 移動狀態
/// [speed] - 速度 (m/s)
/// 返回效率值 (0-1)
double getUnlockEfficiency(MovementState state, double speed) {
  switch (state) {
    case MovementState.stationary:
      return 0;

    case MovementState.walking:
      return 1.0;

    case MovementState.fastWalking:
      // 線性遞減：1.8 → 2.5 m/s 對應 100% → 0%
      final ratio = (speed - GpsConfig.speedMax) /
          (GpsConfig.speedCutoff - GpsConfig.speedMax);
      return (1 - ratio).clamp(0.0, 1.0);

    case MovementState.tooFast:
      return 0;
  }
}
