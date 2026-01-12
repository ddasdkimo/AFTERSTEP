import '../../core/config/constants.dart';
import '../../core/utils/geo_utils.dart';
import '../../data/models/location_point.dart';

/// 漂移過濾器
///
/// 過濾 GPS 漂移，當使用者靜止時忽略不合理的位置跳動。
class DriftFilter {
  /// 靜止中心點
  LocationPoint? _stationaryCenter;

  /// 靜止開始時間
  int _stationaryStartTime = 0;

  /// 處理位置點，判斷是否為漂移
  ///
  /// [point] - 當前位置點
  /// [state] - 移動狀態
  /// 返回 true 表示位置有效，false 表示為漂移
  bool process(LocationPoint point, MovementState state) {
    // 如果不是靜止狀態，重置並返回有效
    if (state != MovementState.stationary) {
      _stationaryCenter = null;
      return true;
    }

    // 第一次進入靜止狀態
    if (_stationaryCenter == null) {
      _stationaryCenter = point;
      _stationaryStartTime = point.timestamp;
      return true;
    }

    // 計算與靜止中心的距離
    final distance = GeoUtils.haversineDistance(
      _stationaryCenter!.latitude,
      _stationaryCenter!.longitude,
      point.latitude,
      point.longitude,
    );

    // 如果距離超過漂移門檻
    if (distance > GpsConfig.driftThreshold) {
      final elapsed = point.timestamp - _stationaryStartTime;

      // 短時間內大距離 = 漂移，忽略此點
      if (elapsed < GpsConfig.driftTimeWindow) {
        return false;
      }

      // 長時間後的移動可能是真實的，重置中心
      _stationaryCenter = null;
      return true;
    }

    return true;
  }

  /// 取得當前靜止中心點
  LocationPoint? get stationaryCenter => _stationaryCenter;

  /// 取得靜止開始時間
  int get stationaryStartTime => _stationaryStartTime;

  /// 檢查是否處於靜止狀態
  bool get isStationary => _stationaryCenter != null;

  /// 重置過濾器
  void reset() {
    _stationaryCenter = null;
    _stationaryStartTime = 0;
  }
}
