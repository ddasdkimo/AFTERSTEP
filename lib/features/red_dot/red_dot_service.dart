import 'dart:async';
import 'dart:math' as math;

import 'package:rxdart/rxdart.dart';

import '../../core/config/constants.dart';
import '../../data/models/cell.dart';
import '../../data/models/red_dot.dart';
import '../cell/geo_encoder.dart';
import 'intensity_calculator.dart';
import 'position_obfuscator.dart';

/// 紅點服務
///
/// 管理紅點的取得、計算和顯示。
class RedDotService {
  /// 建立紅點服務
  RedDotService({
    IntensityCalculator? intensityCalculator,
    PositionObfuscator? positionObfuscator,
    GeoEncoder? geoEncoder,
  })  : _intensityCalc = intensityCalculator ?? IntensityCalculator(),
        _obfuscator = positionObfuscator ?? PositionObfuscator(),
        _geoEncoder = geoEncoder ?? GeoEncoder();

  final IntensityCalculator _intensityCalc;
  final PositionObfuscator _obfuscator;
  final GeoEncoder _geoEncoder;

  /// 快取
  _RedDotCacheEntry? _cache;

  /// 取得活動資料的回調
  Future<List<CellActivity>> Function(List<String> cellIds)?
      _fetchActivitiesCallback;

  /// 紅點更新串流
  final _redDotsUpdatedController = BehaviorSubject<List<RedDot>>();

  /// 紅點更新串流
  Stream<List<RedDot>> get redDotsUpdated => _redDotsUpdatedController.stream;

  /// 當前紅點列表
  List<RedDot> get currentRedDots => _redDotsUpdatedController.valueOrNull ?? [];

  /// 設定取得活動資料的回調
  void setFetchActivitiesCallback(
    Future<List<CellActivity>> Function(List<String> cellIds) callback,
  ) {
    _fetchActivitiesCallback = callback;
  }

  /// 取得視口內的紅點
  ///
  /// [viewport] - 視口邊界
  /// [userUnlockedCells] - 使用者已解鎖的 Cell ID 集合
  /// 返回紅點列表
  Future<List<RedDot>> getRedDotsInViewport(
    ViewportBounds viewport,
    Set<String> userUnlockedCells,
  ) async {
    // 檢查快取是否有效
    if (_isCacheValid(viewport)) {
      return _cache!.dots;
    }

    // 計算視口內的 Cell ID
    final visibleCellIds = _getCellsInViewport(viewport);

    // 過濾出已解鎖的 Cell
    final unlockedVisibleCells =
        visibleCellIds.where((id) => userUnlockedCells.contains(id)).toList();

    if (unlockedVisibleCells.isEmpty) {
      _cache = _RedDotCacheEntry(
        dots: [],
        fetchTime: DateTime.now().millisecondsSinceEpoch,
        viewport: viewport,
      );
      _redDotsUpdatedController.add([]);
      return [];
    }

    // 取得活動資料
    List<CellActivity> activities;
    if (_fetchActivitiesCallback != null) {
      activities = await _fetchActivitiesCallback!(unlockedVisibleCells);
    } else {
      activities = [];
    }

    // 計算強度
    final intensities = _intensityCalc.processActivities(activities);

    // 轉換為紅點
    final dots = _convertToRedDots(intensities, viewport);

    // 更新快取
    _cache = _RedDotCacheEntry(
      dots: dots,
      fetchTime: DateTime.now().millisecondsSinceEpoch,
      viewport: viewport,
    );

    _redDotsUpdatedController.add(dots);

    return dots;
  }

  /// 取得指定 Cell 的紅點
  RedDot? getRedDotForCell(String cellId) {
    return currentRedDots.where((d) => d.cellId == cellId).firstOrNull;
  }

  /// 檢查快取是否有效
  bool _isCacheValid(ViewportBounds viewport) {
    if (_cache == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _cache!.fetchTime > RedDotConfig.cacheTtl) {
      return false;
    }

    // 檢查視口是否相同（允許小幅變化）
    final old = _cache!.viewport;
    const tolerance = 0.001;

    return (old.north - viewport.north).abs() < tolerance &&
        (old.south - viewport.south).abs() < tolerance &&
        (old.east - viewport.east).abs() < tolerance &&
        (old.west - viewport.west).abs() < tolerance;
  }

  /// 取得視口內的 Cell ID
  List<String> _getCellsInViewport(ViewportBounds viewport) {
    final centerLat = (viewport.north + viewport.south) / 2;
    final swCell = _geoEncoder.coordToCell(viewport.south, viewport.west);
    final neCell = _geoEncoder.coordToCell(viewport.north, viewport.east);

    final cellIds = <String>[];

    for (var latIdx = swCell.latIndex; latIdx <= neCell.latIndex; latIdx++) {
      for (var lngIdx = swCell.lngIndex; lngIdx <= neCell.lngIndex; lngIdx++) {
        cellIds.add('$latIdx:$lngIdx');
      }
    }

    return cellIds;
  }

  /// 轉換為紅點
  List<RedDot> _convertToRedDots(
    Map<String, double> intensities,
    ViewportBounds viewport,
  ) {
    final dots = <RedDot>[];
    final centerLat = (viewport.north + viewport.south) / 2;

    for (final entry in intensities.entries) {
      final cellId = entry.key;
      final intensity = entry.value;

      final cell = _geoEncoder.cellIdToCell(cellId, centerLat);
      final displayPos = _obfuscator.applyOffset(cell);

      final size = _calculateSize(intensity);
      final opacity = _calculateOpacity(intensity);

      dots.add(RedDot(
        id: cellId,
        cellId: cellId,
        originalLat: cell.centerLat,
        originalLng: cell.centerLng,
        displayLat: displayPos.lat,
        displayLng: displayPos.lng,
        intensity: intensity,
        size: size,
        opacity: opacity,
        pulsePhase: _seededRandom(cellId.hashCode),
      ));
    }

    // 依強度排序，取前 N 個
    dots.sort((a, b) => b.intensity.compareTo(a.intensity));
    return dots.take(RedDotConfig.maxVisibleDots).toList();
  }

  /// 計算紅點尺寸
  double _calculateSize(double intensity) {
    final t = math.pow(intensity, 0.7);
    return RedDotConfig.dotBaseSize +
        (RedDotConfig.dotMaxSize - RedDotConfig.dotBaseSize) * t;
  }

  /// 計算不透明度
  double _calculateOpacity(double intensity) {
    return 0.3 + intensity * 0.6;
  }

  /// 帶種子的隨機數
  double _seededRandom(int seed) {
    final x = math.sin(seed.toDouble()) * 10000;
    return x - x.floor();
  }

  /// 清空快取
  void clearCache() {
    _cache = null;
  }

  /// 釋放資源
  void dispose() {
    _redDotsUpdatedController.close();
  }
}

/// 紅點快取項目
class _RedDotCacheEntry {
  const _RedDotCacheEntry({
    required this.dots,
    required this.fetchTime,
    required this.viewport,
  });

  final List<RedDot> dots;
  final int fetchTime;
  final ViewportBounds viewport;
}
