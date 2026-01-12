import 'dart:math' as math;

import '../../core/config/constants.dart';
import '../../data/models/cell.dart';

/// 地理編碼器
///
/// 負責將經緯度座標轉換為 Cell 網格座標。
class GeoEncoder {
  /// 將座標轉換為 Cell
  ///
  /// [latitude] - 緯度
  /// [longitude] - 經度
  /// 返回對應的 Cell
  Cell coordToCell(double latitude, double longitude) {
    // 計算每個 Cell 對應的緯度和經度範圍
    final latDegreesPerCell = CellConfig.cellSize / CellConfig.metersPerLatDegree;
    final lngDegreesPerCell =
        CellConfig.cellSize / _metersPerLngDegree(latitude);

    // 計算索引
    final latIndex = (latitude / latDegreesPerCell).floor();
    final lngIndex = (longitude / lngDegreesPerCell).floor();

    // 計算邊界
    final south = latIndex * latDegreesPerCell;
    final north = south + latDegreesPerCell;
    final west = lngIndex * lngDegreesPerCell;
    final east = west + lngDegreesPerCell;

    return Cell(
      cellId: '$latIndex:$lngIndex',
      latIndex: latIndex,
      lngIndex: lngIndex,
      centerLat: (north + south) / 2,
      centerLng: (east + west) / 2,
      bounds: CellBounds(
        north: north,
        south: south,
        east: east,
        west: west,
      ),
    );
  }

  /// 從索引建立 Cell
  ///
  /// [latIndex] - 緯度索引
  /// [lngIndex] - 經度索引
  /// [referenceLatitude] - 參考緯度（用於計算經度跨度）
  /// 返回對應的 Cell
  Cell indexToCell(int latIndex, int lngIndex, double referenceLatitude) {
    final latDegreesPerCell = CellConfig.cellSize / CellConfig.metersPerLatDegree;
    final lngDegreesPerCell =
        CellConfig.cellSize / _metersPerLngDegree(referenceLatitude);

    final south = latIndex * latDegreesPerCell;
    final north = south + latDegreesPerCell;
    final west = lngIndex * lngDegreesPerCell;
    final east = west + lngDegreesPerCell;

    return Cell(
      cellId: '$latIndex:$lngIndex',
      latIndex: latIndex,
      lngIndex: lngIndex,
      centerLat: (north + south) / 2,
      centerLng: (east + west) / 2,
      bounds: CellBounds(
        north: north,
        south: south,
        east: east,
        west: west,
      ),
    );
  }

  /// 解析 Cell ID
  ///
  /// [cellId] - Cell ID 字串 "lat_index:lng_index"
  /// 返回 (latIndex, lngIndex)
  ({int latIndex, int lngIndex}) parseCellId(String cellId) {
    final parts = cellId.split(':');
    return (
      latIndex: int.parse(parts[0]),
      lngIndex: int.parse(parts[1]),
    );
  }

  /// 從 Cell ID 建立 Cell
  ///
  /// [cellId] - Cell ID
  /// [referenceLatitude] - 參考緯度
  /// 返回對應的 Cell
  Cell cellIdToCell(String cellId, double referenceLatitude) {
    final indices = parseCellId(cellId);
    return indexToCell(indices.latIndex, indices.lngIndex, referenceLatitude);
  }

  /// 計算指定緯度處每經度的公尺數
  double _metersPerLngDegree(double latitude) {
    return CellConfig.metersPerLatDegree * math.cos(latitude * math.pi / 180);
  }
}

/// Cell 查詢服務
///
/// 提供鄰近 Cell 查詢和路徑 Cell 計算功能。
class CellQueryService {
  /// 建立查詢服務
  CellQueryService({GeoEncoder? geoEncoder})
      : _geoEncoder = geoEncoder ?? GeoEncoder();

  final GeoEncoder _geoEncoder;

  /// 取得指定位置周圍的 Cell
  ///
  /// [latitude] - 緯度
  /// [longitude] - 經度
  /// [radius] - 查詢半徑（Cell 數量）
  /// 返回周圍的 Cell 列表
  List<Cell> getNearbyCells(
    double latitude,
    double longitude, {
    int radius = CellConfig.nearbyRadius,
  }) {
    final centerCell = _geoEncoder.coordToCell(latitude, longitude);
    final cells = <Cell>[];

    for (var dLat = -radius; dLat <= radius; dLat++) {
      for (var dLng = -radius; dLng <= radius; dLng++) {
        final cell = _geoEncoder.indexToCell(
          centerCell.latIndex + dLat,
          centerCell.lngIndex + dLng,
          latitude,
        );
        cells.add(cell);
      }
    }

    return cells;
  }

  /// 取得路徑經過的所有 Cell
  ///
  /// [startLat], [startLng] - 起點經緯度
  /// [endLat], [endLng] - 終點經緯度
  /// 返回路徑經過的 Cell 列表
  List<Cell> getCellsAlongPath(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    final cells = <String, Cell>{};

    final startCell = _geoEncoder.coordToCell(startLat, startLng);
    final endCell = _geoEncoder.coordToCell(endLat, endLng);

    final dLat = (endCell.latIndex - startCell.latIndex).abs();
    final dLng = (endCell.lngIndex - startCell.lngIndex).abs();
    final steps = math.max(dLat, dLng) + 1;

    for (var i = 0; i <= steps; i++) {
      final t = steps == 0 ? 0.0 : i / steps;
      final lat = startLat + (endLat - startLat) * t;
      final lng = startLng + (endLng - startLng) * t;
      final cell = _geoEncoder.coordToCell(lat, lng);
      cells[cell.cellId] = cell;
    }

    return cells.values.toList();
  }

  /// 取得指定邊界內的所有 Cell ID
  ///
  /// [north], [south], [east], [west] - 邊界
  /// 返回邊界內的 Cell ID 列表
  List<String> getCellIdsInBounds(
    double north,
    double south,
    double east,
    double west,
  ) {
    final centerLat = (north + south) / 2;
    final swCell = _geoEncoder.coordToCell(south, west);
    final neCell = _geoEncoder.coordToCell(north, east);

    final cellIds = <String>[];

    for (var latIdx = swCell.latIndex; latIdx <= neCell.latIndex; latIdx++) {
      for (var lngIdx = swCell.lngIndex; lngIdx <= neCell.lngIndex; lngIdx++) {
        cellIds.add('$latIdx:$lngIdx');
      }
    }

    return cellIds;
  }
}
