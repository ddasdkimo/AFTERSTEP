import 'dart:async';
import 'dart:math' as math;

import 'package:rxdart/rxdart.dart';

import '../../core/config/constants.dart';
import '../../data/models/cell.dart';
import '../../data/models/micro_event.dart';
import '../../data/models/red_dot.dart';
import 'cooldown_manager.dart';
import 'text_selector.dart';

/// 微事件服務
///
/// 管理微事件的觸發、文案選擇和顯示。
class MicroEventService {
  /// 建立微事件服務
  MicroEventService({
    CooldownManager? cooldownManager,
    TextSelector? textSelector,
    math.Random? random,
  })  : _cooldownManager = cooldownManager ?? CooldownManager(),
        _textSelector = textSelector ?? TextSelector(),
        _random = random ?? math.Random();

  final CooldownManager _cooldownManager;
  final TextSelector _textSelector;
  final math.Random _random;

  /// 當前 Cell
  String? _currentCellId;

  /// Cell 進入時間
  int _cellEnterTime = 0;

  /// 檢查計時器
  Timer? _checkTimer;

  /// 紅點查詢回調
  RedDot? Function(String cellId)? _getRedDotForCellCallback;

  /// 顯示事件串流
  final _eventTriggeredController = BehaviorSubject<DisplayEvent>();

  /// 顯示事件串流
  Stream<DisplayEvent> get eventTriggered => _eventTriggeredController.stream;

  /// 當前冷卻管理器
  CooldownManager get cooldownManager => _cooldownManager;

  /// 初始化
  Future<void> initialize() async {
    await _cooldownManager.initialize();
  }

  /// 設定紅點查詢回調
  void setGetRedDotCallback(RedDot? Function(String cellId) callback) {
    _getRedDotForCellCallback = callback;
  }

  /// 處理 Cell 變更
  void onCellChanged(Cell cell) {
    _stopChecking();
    _currentCellId = cell.cellId;
    _cellEnterTime = DateTime.now().millisecondsSinceEpoch;
    _startChecking(cell);
  }

  /// 開始檢查
  void _startChecking(Cell cell) {
    // 檢查是否有紅點
    RedDot? redDot;
    if (_getRedDotForCellCallback != null) {
      redDot = _getRedDotForCellCallback!(cell.cellId);
    }

    // 如果需要紅點但沒有，不啟動檢查
    if (MicroEventConfig.requireRedDot && redDot == null) {
      return;
    }

    // 每秒檢查一次
    _checkTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkTriggerCondition(cell, redDot),
    );
  }

  /// 停止檢查
  void _stopChecking() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// 檢查觸發條件
  void _checkTriggerCondition(Cell cell, RedDot? redDot) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stayDuration = ((now - _cellEnterTime) / 1000).round();

    // 未達到最短停留時間
    if (stayDuration < MicroEventConfig.triggerStayDuration) {
      return;
    }

    // 停止檢查（已達到條件）
    _stopChecking();

    // 建立觸發上下文
    final context = TriggerContext(
      cellId: cell.cellId,
      stayDuration: stayDuration,
      hasRedDot: redDot != null,
      redDotIntensity: redDot?.intensity,
      timestamp: now,
    );

    // 嘗試觸發
    _handleTrigger(context);
  }

  /// 處理觸發
  void _handleTrigger(TriggerContext context) {
    // 1. 檢查冷卻
    final canTrigger = _cooldownManager.canTrigger(context.cellId);
    if (!canTrigger.allowed) {
      return;
    }

    // 2. 機率判定 (25%)
    if (_random.nextDouble() >= MicroEventConfig.triggerProbability) {
      return;
    }

    // 3. 選擇文案
    final event = _textSelector.select(context);

    // 4. 記錄觸發
    _cooldownManager.recordTrigger(context.cellId);

    // 5. 發出顯示事件
    final displayEvent = DisplayEvent(
      id: '${context.cellId}_${context.timestamp}',
      text: event.text,
      startTime: context.timestamp,
      phase: DisplayPhase.fadeIn,
    );

    _eventTriggeredController.add(displayEvent);
  }

  /// 手動觸發（用於測試）
  void manualTrigger(String cellId, {double? redDotIntensity}) {
    final context = TriggerContext(
      cellId: cellId,
      stayDuration: MicroEventConfig.triggerStayDuration,
      hasRedDot: redDotIntensity != null,
      redDotIntensity: redDotIntensity,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    _handleTrigger(context);
  }

  /// 取得今日剩餘次數
  int getRemainingToday() {
    return _cooldownManager.getRemainingToday();
  }

  /// 釋放資源
  void dispose() {
    _stopChecking();
    _eventTriggeredController.close();
  }

  /// 重置
  Future<void> reset() async {
    _stopChecking();
    _currentCellId = null;
    _cellEnterTime = 0;
    await _cooldownManager.reset();
    _textSelector.resetRecentlyUsed();
  }
}
