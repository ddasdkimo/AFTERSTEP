import 'package:flutter/material.dart';

import '../../core/config/constants.dart';
import '../../data/models/micro_event.dart';

/// 微事件覆蓋層 Widget
///
/// 顯示微事件文字，帶有淡入淡出動畫效果。
class MicroEventOverlay extends StatefulWidget {
  const MicroEventOverlay({
    super.key,
    required this.eventStream,
    this.textColor = const Color(0xE6FFFFFF),
    this.fontSize = MicroEventConfig.fontSize,
    this.positionYRatio = MicroEventConfig.positionYRatio,
  });

  /// 事件串流
  final Stream<DisplayEvent> eventStream;

  /// 文字顏色
  final Color textColor;

  /// 字體大小
  final double fontSize;

  /// Y 位置比例
  final double positionYRatio;

  @override
  State<MicroEventOverlay> createState() => _MicroEventOverlayState();
}

class _MicroEventOverlayState extends State<MicroEventOverlay>
    with SingleTickerProviderStateMixin {
  String? _currentText;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    final totalDuration = MicroEventConfig.fadeInDuration +
        MicroEventConfig.displayDuration +
        MicroEventConfig.fadeOutDuration;

    _controller = AnimationController(
      duration: Duration(milliseconds: totalDuration),
      vsync: this,
    );

    // 建立淡入-維持-淡出動畫序列
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: MicroEventConfig.fadeInDuration.toDouble(),
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: MicroEventConfig.displayDuration.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: MicroEventConfig.fadeOutDuration.toDouble(),
      ),
    ]).animate(_controller);

    // 監聽事件串流
    widget.eventStream.listen(_onEvent);
  }

  void _onEvent(DisplayEvent event) {
    setState(() => _currentText = event.text);

    _controller.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _currentText = null);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentText == null) {
      return const SizedBox.shrink();
    }

    final screenHeight = MediaQuery.of(context).size.height;

    return Positioned(
      left: 0,
      right: 0,
      top: screenHeight * widget.positionYRatio,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _currentText!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: widget.fontSize,
                color: widget.textColor,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.2,
                shadows: const [
                  Shadow(
                    blurRadius: 8,
                    color: Color(0x80000000),
                    offset: Offset(0, 2),
                  ),
                  Shadow(
                    blurRadius: 16,
                    color: Color(0x40000000),
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
