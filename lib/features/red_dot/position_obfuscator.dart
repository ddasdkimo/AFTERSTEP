import 'dart:math' as math;

import '../../core/config/constants.dart';
import '../../data/models/cell.dart';

/// 位置模糊器
///
/// 為紅點位置加入模糊偏移，保護隱私。
class PositionObfuscator {
  /// 偏移快取 Map<cellId, (dLat, dLng)>
  final Map<String, ({double dLat, double dLng})> _offsetCache = {};

  /// 取得指定 Cell 的偏移量
  ///
  /// [cellId] - Cell ID
  /// 返回 (dLat, dLng) 偏移量
  ({double dLat, double dLng}) getOffset(String cellId) {
    // 檢查快取
    final cached = _offsetCache[cellId];
    if (cached != null) return cached;

    // 使用 cell_id 作為種子，確保同一 Cell 偏移一致
    final seed = _hashString(cellId);
    final random1 = _seededRandom(seed);
    final random2 = _seededRandom(seed + 1);

    // 計算隨機距離和角度
    final distance = RedDotConfig.offsetMinMeters +
        random1 * (RedDotConfig.offsetMaxMeters - RedDotConfig.offsetMinMeters);
    final angle = random2 * math.pi * 2;

    // 轉換為經緯度偏移
    final dLat = (distance * math.cos(angle)) / CellConfig.metersPerLatDegree;
    final dLng = (distance * math.sin(angle)) / CellConfig.metersPerLatDegree;

    final offset = (dLat: dLat, dLng: dLng);
    _offsetCache[cellId] = offset;

    return offset;
  }

  /// 套用偏移到 Cell 中心
  ///
  /// [cell] - Cell
  /// 返回偏移後的座標
  ({double lat, double lng}) applyOffset(Cell cell) {
    final offset = getOffset(cell.cellId);

    return (
      lat: cell.centerLat + offset.dLat,
      lng: cell.centerLng + offset.dLng,
    );
  }

  /// 套用偏移到座標
  ///
  /// [cellId] - Cell ID
  /// [lat] - 原始緯度
  /// [lng] - 原始經度
  /// 返回偏移後的座標
  ({double lat, double lng}) applyOffsetToCoord(
    String cellId,
    double lat,
    double lng,
  ) {
    final offset = getOffset(cellId);

    return (
      lat: lat + offset.dLat,
      lng: lng + offset.dLng,
    );
  }

  /// 字串雜湊函數
  int _hashString(String str) {
    var hash = 0;
    for (var i = 0; i < str.length; i++) {
      final char = str.codeUnitAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // 轉換為 32 位元整數
    }
    return hash.abs();
  }

  /// 帶種子的隨機數產生器
  double _seededRandom(int seed) {
    final x = math.sin(seed.toDouble()) * 10000;
    return x - x.floor();
  }

  /// 清空偏移快取
  void clearCache() {
    _offsetCache.clear();
  }
}
