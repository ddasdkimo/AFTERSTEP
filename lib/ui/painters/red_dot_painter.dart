import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/config/constants.dart';
import '../../data/models/red_dot.dart';
import 'fog_painter.dart';

/// 紅點渲染器 (CustomPainter)
///
/// 渲染紅點和脈動動畫效果。
class RedDotPainter extends CustomPainter {
  RedDotPainter({
    required this.dots,
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
    required this.animationValue,
  });

  final List<RedDot> dots;
  final double centerLat;
  final double centerLng;
  final double zoom;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final coordSystem = FogCoordinateSystem(
      viewportWidth: size.width,
      viewportHeight: size.height,
      centerLat: centerLat,
      centerLng: centerLng,
      zoom: zoom,
    );

    for (final dot in dots) {
      _renderDot(canvas, coordSystem, dot, size);
    }
  }

  void _renderDot(
    Canvas canvas,
    FogCoordinateSystem coordSystem,
    RedDot dot,
    Size size,
  ) {
    final screenPos = coordSystem.geoToScreen(dot.displayLat, dot.displayLng);

    // 檢查是否在畫面內
    final buffer = 50.0;
    if (screenPos.dx < -buffer ||
        screenPos.dx > size.width + buffer ||
        screenPos.dy < -buffer ||
        screenPos.dy > size.height + buffer) {
      return;
    }

    // 計算脈動效果
    final pulseProgress = ((animationValue + dot.pulsePhase) % 1.0);
    final pulseScale = _calculatePulseScale(pulseProgress, dot.intensity);
    final currentSize = dot.size * pulseScale;

    // 繪製外發光
    _drawGlow(canvas, screenPos, currentSize, dot.opacity);

    // 繪製核心圓點
    _drawCore(canvas, screenPos, currentSize, dot.opacity);
  }

  double _calculatePulseScale(double progress, double intensity) {
    // 使用正弦波產生平滑的脈動效果
    final pulseAmount = intensity * 0.3; // 強度越高，脈動越明顯
    final sineValue = math.sin(progress * math.pi * 2);

    return RedDotConfig.pulseScaleMin +
        (RedDotConfig.pulseScaleMax - RedDotConfig.pulseScaleMin) *
            (0.5 + sineValue * pulseAmount);
  }

  void _drawGlow(Canvas canvas, Offset center, double size, double opacity) {
    final glowRadius = size * 2;

    final gradient = RadialGradient(
      colors: [
        Color.fromRGBO(255, 82, 82, opacity * 0.4),
        Color.fromRGBO(255, 82, 82, opacity * 0.15),
        const Color.fromRGBO(255, 82, 82, 0),
      ],
      stops: const [0, 0.5, 1],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: glowRadius),
      );

    canvas.drawCircle(center, glowRadius, paint);
  }

  void _drawCore(Canvas canvas, Offset center, double size, double opacity) {
    final gradient = RadialGradient(
      colors: [
        Color.fromRGBO(255, 100, 100, opacity),
        Color.fromRGBO(255, 82, 82, opacity * 0.8),
        const Color.fromRGBO(255, 60, 60, 0),
      ],
      stops: const [0, 0.6, 1],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: size),
      );

    canvas.drawCircle(center, size, paint);
  }

  @override
  bool shouldRepaint(covariant RedDotPainter oldDelegate) {
    return dots != oldDelegate.dots ||
        centerLat != oldDelegate.centerLat ||
        centerLng != oldDelegate.centerLng ||
        zoom != oldDelegate.zoom ||
        animationValue != oldDelegate.animationValue;
  }
}
