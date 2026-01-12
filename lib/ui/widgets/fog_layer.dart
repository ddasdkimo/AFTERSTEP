import 'package:flutter/material.dart';

import '../../data/models/unlock_point.dart';
import '../painters/fog_painter.dart';

/// Fog 圖層 Widget
///
/// 顯示 Fog of War 效果，覆蓋在地圖上方。
class FogLayer extends StatelessWidget {
  const FogLayer({
    super.key,
    required this.points,
    required this.paths,
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
    this.fogColor = const Color(0xFF0F0F14),
    this.enabled = true,
  });

  /// 解鎖點列表
  final List<UnlockPoint> points;

  /// 解鎖軌跡列表
  final List<UnlockPath> paths;

  /// 地圖中心緯度
  final double centerLat;

  /// 地圖中心經度
  final double centerLng;

  /// 縮放等級
  final double zoom;

  /// 霧的顏色
  final Color fogColor;

  /// 是否啟用
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: CustomPaint(
        painter: FogPainter(
          points: points,
          paths: paths,
          centerLat: centerLat,
          centerLng: centerLng,
          zoom: zoom,
          fogColor: fogColor,
        ),
        size: Size.infinite,
        isComplex: true,
        willChange: true,
      ),
    );
  }
}

/// Fog 動畫控制器
///
/// 管理解鎖動畫效果。
class FogAnimationController {
  FogAnimationController({
    required TickerProvider vsync,
  }) : _vsync = vsync;

  final TickerProvider _vsync;
  final Map<String, AnimationController> _animations = {};

  /// 開始解鎖動畫
  void animateUnlock(
    String pointId,
    Duration duration,
    VoidCallback onComplete,
  ) {
    final controller = AnimationController(
      duration: duration,
      vsync: _vsync,
    );

    _animations[pointId] = controller;

    controller.forward().then((_) {
      onComplete();
      controller.dispose();
      _animations.remove(pointId);
    });
  }

  /// 取得動畫進度
  double getProgress(String pointId) {
    return _animations[pointId]?.value ?? 1.0;
  }

  /// 是否正在動畫
  bool isAnimating(String pointId) {
    return _animations.containsKey(pointId);
  }

  /// 釋放資源
  void dispose() {
    for (final controller in _animations.values) {
      controller.dispose();
    }
    _animations.clear();
  }
}
