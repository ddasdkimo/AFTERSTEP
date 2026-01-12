import 'package:flutter/material.dart';

import '../../core/config/constants.dart';
import '../../data/models/red_dot.dart';
import '../painters/red_dot_painter.dart';

/// 紅點圖層 Widget
///
/// 顯示紅點（他人存在痕跡）並帶有脈動動畫效果。
class RedDotLayer extends StatefulWidget {
  const RedDotLayer({
    super.key,
    required this.dots,
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
    this.enabled = true,
  });

  /// 紅點列表
  final List<RedDot> dots;

  /// 地圖中心緯度
  final double centerLat;

  /// 地圖中心經度
  final double centerLng;

  /// 縮放等級
  final double zoom;

  /// 是否啟用
  final bool enabled;

  @override
  State<RedDotLayer> createState() => _RedDotLayerState();
}

class _RedDotLayerState extends State<RedDotLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: RedDotConfig.pulseDuration),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.dots.isEmpty) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, _) {
          return CustomPaint(
            painter: RedDotPainter(
              dots: widget.dots,
              centerLat: widget.centerLat,
              centerLng: widget.centerLng,
              zoom: widget.zoom,
              animationValue: _animationController.value,
            ),
            size: Size.infinite,
            isComplex: true,
            willChange: true,
          );
        },
      ),
    );
  }
}
