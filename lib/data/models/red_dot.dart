import 'package:equatable/equatable.dart';

/// 紅點
///
/// 表示地圖上一個紅點（他人存在痕跡）。
class RedDot extends Equatable {
  /// 建立紅點
  const RedDot({
    required this.id,
    required this.cellId,
    required this.originalLat,
    required this.originalLng,
    required this.displayLat,
    required this.displayLng,
    required this.intensity,
    required this.size,
    required this.opacity,
    required this.pulsePhase,
  });

  /// 唯一識別符
  final String id;

  /// 所屬 Cell ID
  final String cellId;

  /// 原始緯度 (Cell 中心)
  final double originalLat;

  /// 原始經度 (Cell 中心)
  final double originalLng;

  /// 顯示緯度 (加入模糊偏移後)
  final double displayLat;

  /// 顯示經度 (加入模糊偏移後)
  final double displayLng;

  /// 強度 (0-1)
  final double intensity;

  /// 尺寸 (像素)
  final double size;

  /// 不透明度 (0-1)
  final double opacity;

  /// 脈動相位 (0-1)
  final double pulsePhase;

  @override
  List<Object?> get props => [
        id,
        cellId,
        originalLat,
        originalLng,
        displayLat,
        displayLng,
        intensity,
        size,
        opacity,
        pulsePhase,
      ];

  /// 複製並修改
  RedDot copyWith({
    String? id,
    String? cellId,
    double? originalLat,
    double? originalLng,
    double? displayLat,
    double? displayLng,
    double? intensity,
    double? size,
    double? opacity,
    double? pulsePhase,
  }) {
    return RedDot(
      id: id ?? this.id,
      cellId: cellId ?? this.cellId,
      originalLat: originalLat ?? this.originalLat,
      originalLng: originalLng ?? this.originalLng,
      displayLat: displayLat ?? this.displayLat,
      displayLng: displayLng ?? this.displayLng,
      intensity: intensity ?? this.intensity,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      pulsePhase: pulsePhase ?? this.pulsePhase,
    );
  }
}

/// 視口邊界
///
/// 表示地圖當前可見區域的邊界。
class ViewportBounds extends Equatable {
  /// 建立視口邊界
  const ViewportBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
    required this.zoom,
  });

  /// 北邊界緯度
  final double north;

  /// 南邊界緯度
  final double south;

  /// 東邊界經度
  final double east;

  /// 西邊界經度
  final double west;

  /// 縮放等級
  final double zoom;

  @override
  List<Object?> get props => [north, south, east, west, zoom];

  /// 檢查座標是否在視口內
  bool contains(double lat, double lng) {
    return lat >= south && lat <= north && lng >= west && lng <= east;
  }

  /// 複製並修改
  ViewportBounds copyWith({
    double? north,
    double? south,
    double? east,
    double? west,
    double? zoom,
  }) {
    return ViewportBounds(
      north: north ?? this.north,
      south: south ?? this.south,
      east: east ?? this.east,
      west: west ?? this.west,
      zoom: zoom ?? this.zoom,
    );
  }
}
