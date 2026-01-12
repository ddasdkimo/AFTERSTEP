import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/config/constants.dart';
import '../../data/models/unlock_point.dart';

/// Fog 座標系統
///
/// 處理經緯度到螢幕座標的轉換。
class FogCoordinateSystem {
  FogCoordinateSystem({
    required this.viewportWidth,
    required this.viewportHeight,
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
  });

  final double viewportWidth;
  final double viewportHeight;
  final double centerLat;
  final double centerLng;
  final double zoom;

  /// 經緯度轉換為螢幕座標
  Offset geoToScreen(double lat, double lng) {
    final scale = math.pow(2, zoom) * 256;

    // 中心點的世界座標
    final centerX = (centerLng + 180) / 360 * scale;
    final centerLatRad = centerLat * math.pi / 180;
    final centerY =
        (1 - math.log(math.tan(centerLatRad) + 1 / math.cos(centerLatRad)) / math.pi) /
            2 *
            scale;

    // 目標點的世界座標
    final x = (lng + 180) / 360 * scale;
    final latRad = lat * math.pi / 180;
    final y =
        (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * scale;

    // 轉換為螢幕座標
    final screenX = viewportWidth / 2 + (x - centerX);
    final screenY = viewportHeight / 2 + (y - centerY);

    return Offset(screenX, screenY);
  }

  /// 公尺轉換為像素
  double metersToPixels(double meters, double latitude) {
    final metersPerPixel =
        156543.03392 * math.cos(latitude * math.pi / 180) / math.pow(2, zoom);
    return meters / metersPerPixel;
  }
}

/// Fog 渲染器 (CustomPainter)
///
/// 使用 Circle Stamp 技術渲染 Fog of War。
class FogPainter extends CustomPainter {
  FogPainter({
    required this.points,
    required this.paths,
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
    this.fogColor = const Color(0xFF0F0F14),
    this.edgeBlur = FogConfig.fogEdgeBlur,
  });

  final List<UnlockPoint> points;
  final List<UnlockPath> paths;
  final double centerLat;
  final double centerLng;
  final double zoom;
  final Color fogColor;
  final double edgeBlur;

  @override
  void paint(Canvas canvas, Size size) {
    final coordSystem = FogCoordinateSystem(
      viewportWidth: size.width,
      viewportHeight: size.height,
      centerLat: centerLat,
      centerLng: centerLng,
      zoom: zoom,
    );

    // 建立霧層
    canvas.saveLayer(Offset.zero & size, Paint());

    // 1. 填滿黑霧
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = fogColor,
    );

    // 2. 使用 BlendMode.dstOut 擦除解鎖區域
    final erasePaint = Paint()..blendMode = BlendMode.dstOut;

    // 3. 繪製所有解鎖軌跡
    for (final path in paths) {
      _drawPath(canvas, coordSystem, path, erasePaint);
    }

    // 4. 繪製所有解鎖點
    for (final point in points) {
      _drawPoint(canvas, coordSystem, point, erasePaint);
    }

    canvas.restore();
  }

  /// 繪製解鎖點
  void _drawPoint(
    Canvas canvas,
    FogCoordinateSystem coordSystem,
    UnlockPoint point,
    Paint basePaint,
  ) {
    final screenPos = coordSystem.geoToScreen(point.latitude, point.longitude);
    final radiusPx = coordSystem.metersToPixels(point.radius, point.latitude);

    // 檢查是否在畫面內（加上緩衝區）
    if (screenPos.dx < -radiusPx * 2 ||
        screenPos.dx > coordSystem.viewportWidth + radiusPx * 2 ||
        screenPos.dy < -radiusPx * 2 ||
        screenPos.dy > coordSystem.viewportHeight + radiusPx * 2) {
      return;
    }

    // 建立徑向漸層
    final gradient = ui.Gradient.radial(
      screenPos,
      radiusPx,
      [
        Colors.white,
        Colors.white,
        Colors.white.withValues(alpha: 0),
      ],
      [0, 1 - edgeBlur, 1],
    );

    final paint = Paint()
      ..shader = gradient
      ..blendMode = BlendMode.dstOut;

    canvas.drawCircle(screenPos, radiusPx, paint);
  }

  /// 繪製解鎖軌跡
  void _drawPath(
    Canvas canvas,
    FogCoordinateSystem coordSystem,
    UnlockPath path,
    Paint basePaint,
  ) {
    if (path.points.length < 2) return;

    final pathPoints = path.points.map((p) {
      return coordSystem.geoToScreen(p.lat, p.lng);
    }).toList();

    // 計算軌跡寬度（使用第一個點的緯度）
    final widthPx = coordSystem.metersToPixels(
      path.width,
      path.points.first.lat,
    );

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = widthPx
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = BlendMode.dstOut;

    final pathObj = Path();
    pathObj.moveTo(pathPoints.first.dx, pathPoints.first.dy);

    for (var i = 1; i < pathPoints.length; i++) {
      pathObj.lineTo(pathPoints[i].dx, pathPoints[i].dy);
    }

    canvas.drawPath(pathObj, paint);
  }

  @override
  bool shouldRepaint(covariant FogPainter oldDelegate) {
    return points != oldDelegate.points ||
        paths != oldDelegate.paths ||
        centerLat != oldDelegate.centerLat ||
        centerLng != oldDelegate.centerLng ||
        zoom != oldDelegate.zoom;
  }
}
