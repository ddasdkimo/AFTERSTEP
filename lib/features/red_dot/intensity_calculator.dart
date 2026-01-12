import 'dart:math' as math;

import '../../core/config/constants.dart';
import '../../data/models/cell.dart';

/// 強度計算器
///
/// 計算紅點的強度（基於時間衰減）。
class IntensityCalculator {
  /// τ 值（毫秒）
  final int _tauMs =
      (RedDotConfig.decayTauDays * 24 * 60 * 60 * 1000).round();

  /// 計算單個活動的強度
  ///
  /// [lastActivityTime] - 最後活動時間（毫秒）
  /// 返回強度值 (0-1)
  double calculate(int lastActivityTime) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final deltaMs = now - lastActivityTime;

    if (deltaMs < 0) return 1.0;

    // 指數衰減：intensity = exp(-Δt / τ)
    return math.exp(-deltaMs / _tauMs);
  }

  /// 處理多個 Cell 活動
  ///
  /// [activities] - Cell 活動列表
  /// 返回 Map<cellId, intensity>，只包含強度高於門檻的 Cell
  Map<String, double> processActivities(List<CellActivity> activities) {
    final result = <String, double>{};

    for (final activity in activities) {
      final intensity = calculate(activity.lastActivityTime);

      if (intensity >= RedDotConfig.intensityThreshold) {
        result[activity.cellId] = intensity;
      }
    }

    return result;
  }

  /// 檢查活動是否仍然有效（強度高於門檻）
  bool isActivityValid(int lastActivityTime) {
    return calculate(lastActivityTime) >= RedDotConfig.intensityThreshold;
  }

  /// 計算強度達到門檻的最大時間差（毫秒）
  int get maxValidDeltaMs {
    // intensity = exp(-Δt / τ) >= threshold
    // -Δt / τ >= ln(threshold)
    // Δt <= -τ * ln(threshold)
    return (-_tauMs * math.log(RedDotConfig.intensityThreshold)).round();
  }
}
