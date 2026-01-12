import 'dart:math' as math;

/// 地理計算工具類
///
/// 提供 Haversine 距離計算、座標轉換等地理相關工具函數。
class GeoUtils {
  GeoUtils._();

  /// 地球半徑 (公尺)
  static const double earthRadius = 6371000.0;

  /// 每緯度公尺數
  static const double metersPerLatDegree = 111320.0;

  /// 計算兩點之間的 Haversine 距離 (公尺)
  ///
  /// [lat1], [lng1] - 起點經緯度
  /// [lat2], [lng2] - 終點經緯度
  /// 返回兩點之間的距離 (公尺)
  static double haversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaPhi = (lat2 - lat1) * math.pi / 180;
    final deltaLambda = (lng2 - lng1) * math.pi / 180;

    final a = math.pow(math.sin(deltaPhi / 2), 2) +
        math.cos(phi1) * math.cos(phi2) * math.pow(math.sin(deltaLambda / 2), 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// 計算指定緯度處每經度的公尺數
  ///
  /// [latitude] - 緯度
  /// 返回該緯度處每經度的公尺數
  static double metersPerLngDegree(double latitude) {
    return metersPerLatDegree * math.cos(latitude * math.pi / 180);
  }

  /// 經緯度轉換為 Web Mercator 投影座標
  ///
  /// [lat], [lng] - 經緯度
  /// [zoom] - 縮放等級
  /// 返回 (x, y) 像素座標
  static ({double x, double y}) geoToMercator(
    double lat,
    double lng,
    double zoom,
  ) {
    final scale = math.pow(2, zoom) * 256;

    final x = (lng + 180) / 360 * scale;
    final latRad = lat * math.pi / 180;
    final y =
        (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
            2 *
            scale;

    return (x: x, y: y);
  }

  /// 公尺轉換為像素 (在指定緯度和縮放等級下)
  ///
  /// [meters] - 公尺數
  /// [latitude] - 緯度
  /// [zoom] - 縮放等級
  /// 返回像素數
  static double metersToPixels(double meters, double latitude, double zoom) {
    final metersPerPixel =
        156543.03392 * math.cos(latitude * math.pi / 180) / math.pow(2, zoom);
    return meters / metersPerPixel;
  }

  /// 像素轉換為公尺 (在指定緯度和縮放等級下)
  ///
  /// [pixels] - 像素數
  /// [latitude] - 緯度
  /// [zoom] - 縮放等級
  /// 返回公尺數
  static double pixelsToMeters(double pixels, double latitude, double zoom) {
    final metersPerPixel =
        156543.03392 * math.cos(latitude * math.pi / 180) / math.pow(2, zoom);
    return pixels * metersPerPixel;
  }

  /// 計算從一點按指定角度和距離偏移後的座標
  ///
  /// [lat], [lng] - 起點經緯度
  /// [distance] - 偏移距離 (公尺)
  /// [bearing] - 方位角 (弧度，0 為正北，順時針)
  /// 返回偏移後的經緯度
  static ({double lat, double lng}) offsetCoordinate(
    double lat,
    double lng,
    double distance,
    double bearing,
  ) {
    final latRad = lat * math.pi / 180;
    final lngRad = lng * math.pi / 180;
    final d = distance / earthRadius;

    final newLatRad = math.asin(
      math.sin(latRad) * math.cos(d) +
          math.cos(latRad) * math.sin(d) * math.cos(bearing),
    );

    final newLngRad = lngRad +
        math.atan2(
          math.sin(bearing) * math.sin(d) * math.cos(latRad),
          math.cos(d) - math.sin(latRad) * math.sin(newLatRad),
        );

    return (
      lat: newLatRad * 180 / math.pi,
      lng: newLngRad * 180 / math.pi,
    );
  }

  /// 計算兩點之間的方位角 (弧度)
  ///
  /// [lat1], [lng1] - 起點經緯度
  /// [lat2], [lng2] - 終點經緯度
  /// 返回方位角 (弧度，0 為正北，順時針)
  static double bearing(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaLambda = (lng2 - lng1) * math.pi / 180;

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

    return math.atan2(y, x);
  }

  /// 簡單的座標偏移 (適用於小範圍)
  ///
  /// [lat], [lng] - 原始經緯度
  /// [dLatMeters] - 緯度方向偏移 (公尺，正值向北)
  /// [dLngMeters] - 經度方向偏移 (公尺，正值向東)
  /// 返回偏移後的經緯度
  static ({double lat, double lng}) simpleOffset(
    double lat,
    double lng,
    double dLatMeters,
    double dLngMeters,
  ) {
    final dLat = dLatMeters / metersPerLatDegree;
    final dLng = dLngMeters / metersPerLngDegree(lat);

    return (
      lat: lat + dLat,
      lng: lng + dLng,
    );
  }
}
