import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/constants.dart';
import '../../data/models/micro_event.dart';

/// 冷卻管理器
///
/// 管理微事件的冷卻狀態，包括 Cell 冷卻和每日上限。
class CooldownManager {
  /// 建立冷卻管理器
  CooldownManager({
    SharedPreferences? prefs,
  }) : _prefs = prefs;

  SharedPreferences? _prefs;
  CooldownState _state = CooldownState.empty;

  /// 儲存鍵
  static const String _storageKey = 'micro_event_cooldown';

  /// 當前狀態
  CooldownState get state => _state;

  /// 初始化
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _loadState();
    _checkDailyReset();
  }

  /// 檢查是否可以觸發
  ///
  /// [cellId] - Cell ID
  /// 返回 (allowed, reason)
  ({bool allowed, String? reason}) canTrigger(String cellId) {
    _checkDailyReset();

    // 檢查每日上限
    if (_state.dailyCount >= MicroEventConfig.dailyMaxEvents) {
      return (allowed: false, reason: 'daily_limit_reached');
    }

    // 檢查 Cell 冷卻
    final cooldownEnd = _state.cellCooldowns[cellId];
    if (cooldownEnd != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now < cooldownEnd) {
        return (allowed: false, reason: 'cell_cooldown');
      }
    }

    return (allowed: true, reason: null);
  }

  /// 記錄觸發
  Future<void> recordTrigger(String cellId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cooldownEnd =
        now + MicroEventConfig.cellCooldownHours * 60 * 60 * 1000;

    final newCooldowns = Map<String, int>.from(_state.cellCooldowns);
    newCooldowns[cellId] = cooldownEnd;

    _state = _state.copyWith(
      cellCooldowns: newCooldowns,
      dailyCount: _state.dailyCount + 1,
    );

    _cleanExpiredCooldowns();
    await _saveState();
  }

  /// 取得今日剩餘次數
  int getRemainingToday() {
    _checkDailyReset();
    return MicroEventConfig.dailyMaxEvents - _state.dailyCount;
  }

  /// 取得 Cell 冷卻剩餘時間（毫秒）
  int? getCellCooldownRemaining(String cellId) {
    final cooldownEnd = _state.cellCooldowns[cellId];
    if (cooldownEnd == null) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final remaining = cooldownEnd - now;

    return remaining > 0 ? remaining : null;
  }

  /// 檢查每日重置
  void _checkDailyReset() {
    final todayStart = _getTodayStartTime();

    if (_state.dailyResetTime < todayStart) {
      _state = _state.copyWith(
        dailyCount: 0,
        dailyResetTime: todayStart,
      );
      _saveState();
    }
  }

  /// 取得今天開始時間（凌晨 4 點）
  int _getTodayStartTime() {
    final now = DateTime.now();
    var today = DateTime(now.year, now.month, now.day, 4, 0, 0);

    if (now.isBefore(today)) {
      today = today.subtract(const Duration(days: 1));
    }

    return today.millisecondsSinceEpoch;
  }

  /// 清理過期冷卻
  void _cleanExpiredCooldowns() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final newCooldowns = Map<String, int>.from(_state.cellCooldowns);

    newCooldowns.removeWhere((_, end) => end <= now);

    if (newCooldowns.length != _state.cellCooldowns.length) {
      _state = _state.copyWith(cellCooldowns: newCooldowns);
    }
  }

  /// 載入狀態
  Future<void> _loadState() async {
    final json = _prefs?.getString(_storageKey);
    if (json != null) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        _state = CooldownState.fromMap(map);
      } catch (e) {
        _state = CooldownState.empty;
      }
    }
  }

  /// 儲存狀態
  Future<void> _saveState() async {
    final json = jsonEncode(_state.toMap());
    await _prefs?.setString(_storageKey, json);
  }

  /// 重置（用於測試）
  Future<void> reset() async {
    _state = CooldownState.empty;
    await _prefs?.remove(_storageKey);
  }
}
