import 'dart:math' as math;

import '../../data/models/micro_event.dart';
import 'micro_event_texts.dart';

/// 文案選擇器
///
/// 根據上下文選擇適合的微事件文案。
class TextSelector {
  /// 建立文案選擇器
  TextSelector({
    List<MicroEventDefinition>? events,
    math.Random? random,
  })  : _events = events ?? microEventTexts,
        _random = random ?? math.Random();

  final List<MicroEventDefinition> _events;
  final math.Random _random;

  /// 最近使用的文案 ID
  final List<String> _recentlyUsed = [];

  /// 最近使用上限
  static const int _recentLimit = 5;

  /// 選擇文案
  ///
  /// [context] - 觸發上下文
  /// 返回選中的文案
  MicroEventDefinition select(TriggerContext context) {
    // 過濾掉最近使用的
    final available =
        _events.where((e) => !_recentlyUsed.contains(e.id)).toList();

    // 如果都用過了，重置
    final pool = available.isNotEmpty ? available : _events;

    // 套用上下文權重
    final weighted = _applyContextWeight(pool, context);

    // 加權隨機選擇
    final selected = _weightedRandom(weighted);

    // 記錄使用
    _recordUsage(selected.id);

    return selected;
  }

  /// 套用上下文權重
  List<_WeightedEvent> _applyContextWeight(
    List<MicroEventDefinition> events,
    TriggerContext context,
  ) {
    return events.map((event) {
      var weight = event.weight.toDouble();

      // 紅點強度高 → 偏好「連結感」類
      if (context.redDotIntensity != null && context.redDotIntensity! > 0.7) {
        if (event.category == EventCategory.connection) {
          weight *= 1.5;
        }
      }

      // 停留時間長 → 偏好「時間感」類
      if (context.stayDuration > 90) {
        if (event.category == EventCategory.time) {
          weight *= 1.3;
        }
      }

      return _WeightedEvent(event: event, weight: weight);
    }).toList();
  }

  /// 加權隨機選擇
  MicroEventDefinition _weightedRandom(List<_WeightedEvent> events) {
    final totalWeight = events.fold<double>(0, (sum, e) => sum + e.weight);
    var random = _random.nextDouble() * totalWeight;

    for (final item in events) {
      random -= item.weight;
      if (random <= 0) return item.event;
    }

    return events.last.event;
  }

  /// 記錄使用
  void _recordUsage(String id) {
    _recentlyUsed.add(id);
    if (_recentlyUsed.length > _recentLimit) {
      _recentlyUsed.removeAt(0);
    }
  }

  /// 重置最近使用記錄
  void resetRecentlyUsed() {
    _recentlyUsed.clear();
  }
}

/// 帶權重的事件
class _WeightedEvent {
  const _WeightedEvent({
    required this.event,
    required this.weight,
  });

  final MicroEventDefinition event;
  final double weight;
}
