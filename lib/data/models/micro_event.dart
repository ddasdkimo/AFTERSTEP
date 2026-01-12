import 'package:equatable/equatable.dart';

/// 事件類別枚舉
enum EventCategory {
  /// 存在感
  presence,

  /// 時間感
  time,

  /// 空間感
  space,

  /// 連結感
  connection,
}

/// 微事件定義
///
/// 定義微事件的文案和權重。
class MicroEventDefinition extends Equatable {
  /// 建立微事件定義
  const MicroEventDefinition({
    required this.id,
    required this.text,
    required this.category,
    required this.weight,
  });

  /// 唯一識別符
  final String id;

  /// 顯示文字
  final String text;

  /// 事件類別
  final EventCategory category;

  /// 選擇權重
  final int weight;

  @override
  List<Object?> get props => [id, text, category, weight];
}

/// 觸發上下文
///
/// 微事件觸發時的環境資訊。
class TriggerContext extends Equatable {
  /// 建立觸發上下文
  const TriggerContext({
    required this.cellId,
    required this.stayDuration,
    required this.hasRedDot,
    this.redDotIntensity,
    required this.timestamp,
  });

  /// Cell ID
  final String cellId;

  /// 停留時長 (秒)
  final int stayDuration;

  /// 是否有紅點
  final bool hasRedDot;

  /// 紅點強度 (0-1)
  final double? redDotIntensity;

  /// 時間戳記 (毫秒)
  final int timestamp;

  @override
  List<Object?> get props => [
        cellId,
        stayDuration,
        hasRedDot,
        redDotIntensity,
        timestamp,
      ];
}

/// 冷卻狀態
///
/// 記錄微事件的冷卻狀態。
class CooldownState extends Equatable {
  /// 建立冷卻狀態
  const CooldownState({
    required this.cellCooldowns,
    required this.dailyCount,
    required this.dailyResetTime,
  });

  /// 空狀態
  static const empty = CooldownState(
    cellCooldowns: {},
    dailyCount: 0,
    dailyResetTime: 0,
  );

  /// Cell 冷卻時間 Map<cell_id, cooldown_end_time>
  final Map<String, int> cellCooldowns;

  /// 今日觸發次數
  final int dailyCount;

  /// 每日重置時間 (毫秒)
  final int dailyResetTime;

  @override
  List<Object?> get props => [cellCooldowns, dailyCount, dailyResetTime];

  /// 從 Map 建立
  factory CooldownState.fromMap(Map<String, dynamic> map) {
    return CooldownState(
      cellCooldowns: Map<String, int>.from(map['cell_cooldowns'] as Map? ?? {}),
      dailyCount: map['daily_count'] as int? ?? 0,
      dailyResetTime: map['daily_reset_time'] as int? ?? 0,
    );
  }

  /// 轉換為 Map
  Map<String, dynamic> toMap() {
    return {
      'cell_cooldowns': cellCooldowns,
      'daily_count': dailyCount,
      'daily_reset_time': dailyResetTime,
    };
  }

  /// 複製並修改
  CooldownState copyWith({
    Map<String, int>? cellCooldowns,
    int? dailyCount,
    int? dailyResetTime,
  }) {
    return CooldownState(
      cellCooldowns: cellCooldowns ?? this.cellCooldowns,
      dailyCount: dailyCount ?? this.dailyCount,
      dailyResetTime: dailyResetTime ?? this.dailyResetTime,
    );
  }
}

/// 顯示階段枚舉
enum DisplayPhase {
  /// 淡入
  fadeIn,

  /// 可見
  visible,

  /// 淡出
  fadeOut,

  /// 完成
  done,
}

/// 顯示事件
///
/// 表示正在顯示的微事件。
class DisplayEvent extends Equatable {
  /// 建立顯示事件
  const DisplayEvent({
    required this.id,
    required this.text,
    required this.startTime,
    required this.phase,
  });

  /// 唯一識別符
  final String id;

  /// 顯示文字
  final String text;

  /// 開始時間 (毫秒)
  final int startTime;

  /// 顯示階段
  final DisplayPhase phase;

  @override
  List<Object?> get props => [id, text, startTime, phase];

  /// 複製並修改
  DisplayEvent copyWith({
    String? id,
    String? text,
    int? startTime,
    DisplayPhase? phase,
  }) {
    return DisplayEvent(
      id: id ?? this.id,
      text: text ?? this.text,
      startTime: startTime ?? this.startTime,
      phase: phase ?? this.phase,
    );
  }
}
