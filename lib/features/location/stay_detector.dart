import '../../core/config/constants.dart';
import '../../core/utils/geo_utils.dart';
import '../../data/models/location_point.dart';

/// 停留偵測器
///
/// 偵測使用者在某處停留的行為，用於觸發停留擴散和微事件。
class StayDetector {
  /// 停留點緩衝區
  final List<LocationPoint> _points = [];

  /// 當前停留事件
  StayEvent? _currentStay;

  /// 處理位置點，偵測停留事件
  ///
  /// [point] - 當前位置點
  /// 返回完成的停留事件（如果有），null 表示停留未結束
  StayEvent? process(LocationPoint point) {
    _points.add(point);
    _pruneOldPoints(point.timestamp);

    if (_points.isEmpty) return null;

    // 計算所有點的中心
    final center = _calculateCenter();

    // 檢查所有點是否都在停留半徑內
    final allWithinRadius = _points.every((p) {
      final distance = GeoUtils.haversineDistance(
        center.lat,
        center.lng,
        p.latitude,
        p.longitude,
      );
      return distance <= GpsConfig.stayRadius;
    });

    // 如果有點超出範圍，說明用戶離開了
    if (!allWithinRadius) {
      final completedStay = _currentStay;
      _currentStay = null;
      _points.clear();
      _points.add(point);
      return completedStay;
    }

    // 計算停留時長
    final duration =
        ((point.timestamp - _points.first.timestamp) / 1000).round();

    // 達到最短停留時間，更新或建立停留事件
    if (duration >= GpsConfig.stayMinDuration) {
      if (_currentStay == null) {
        _currentStay = StayEvent(
          centerLat: center.lat,
          centerLng: center.lng,
          startTime: _points.first.timestamp,
          duration: duration,
          radius: GpsConfig.stayRadius,
        );
      } else {
        _currentStay = _currentStay!.copyWith(
          centerLat: center.lat,
          centerLng: center.lng,
          duration: duration,
        );
      }
    }

    return null;
  }

  /// 清理舊的位置點 (保留最近 2 分鐘)
  void _pruneOldPoints(int now) {
    final cutoff = now - 120000; // 2 分鐘
    _points.removeWhere((p) => p.timestamp < cutoff);
  }

  /// 計算中心點
  ({double lat, double lng}) _calculateCenter() {
    if (_points.isEmpty) return (lat: 0, lng: 0);

    final lat =
        _points.map((p) => p.latitude).reduce((a, b) => a + b) / _points.length;
    final lng = _points.map((p) => p.longitude).reduce((a, b) => a + b) /
        _points.length;

    return (lat: lat, lng: lng);
  }

  /// 取得當前停留事件（進行中）
  StayEvent? get currentStay => _currentStay;

  /// 檢查是否正在停留
  bool get isStaying => _currentStay != null;

  /// 取得當前停留時長（秒）
  int get currentStayDuration {
    if (_points.length < 2) return 0;
    return ((_points.last.timestamp - _points.first.timestamp) / 1000).round();
  }

  /// 強制結束當前停留並返回事件
  StayEvent? endCurrentStay() {
    final stay = _currentStay;
    _currentStay = null;
    _points.clear();
    return stay;
  }

  /// 重置偵測器
  void reset() {
    _points.clear();
    _currentStay = null;
  }
}
