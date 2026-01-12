import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/constants.dart';
import 'push_messages.dart';

/// 推播狀態
class PushState {
  const PushState({
    required this.lastPushTime,
    required this.lastPushDate,
    required this.todayPushCount,
    required this.permissionGranted,
  });

  final int lastPushTime;
  final String lastPushDate;
  final int todayPushCount;
  final bool permissionGranted;

  static const empty = PushState(
    lastPushTime: 0,
    lastPushDate: '',
    todayPushCount: 0,
    permissionGranted: false,
  );

  factory PushState.fromMap(Map<String, dynamic> map) {
    return PushState(
      lastPushTime: map['last_push_time'] as int? ?? 0,
      lastPushDate: map['last_push_date'] as String? ?? '',
      todayPushCount: map['today_push_count'] as int? ?? 0,
      permissionGranted: map['permission_granted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'last_push_time': lastPushTime,
      'last_push_date': lastPushDate,
      'today_push_count': todayPushCount,
      'permission_granted': permissionGranted,
    };
  }

  PushState copyWith({
    int? lastPushTime,
    String? lastPushDate,
    int? todayPushCount,
    bool? permissionGranted,
  }) {
    return PushState(
      lastPushTime: lastPushTime ?? this.lastPushTime,
      lastPushDate: lastPushDate ?? this.lastPushDate,
      todayPushCount: todayPushCount ?? this.todayPushCount,
      permissionGranted: permissionGranted ?? this.permissionGranted,
    );
  }
}

/// 推播服務
///
/// 管理本地推播，在解鎖新區域時發送通知。
class PushService {
  /// 建立推播服務
  PushService({
    SharedPreferences? prefs,
    PushMessageSelector? messageSelector,
  })  : _prefs = prefs,
        _messageSelector = messageSelector ?? PushMessageSelector();

  SharedPreferences? _prefs;
  final PushMessageSelector _messageSelector;
  PushState _state = PushState.empty;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _storageKey = 'push_state';

  /// 當前狀態
  PushState get state => _state;

  /// 是否已授權
  bool get isPermissionGranted => _state.permissionGranted;

  /// 初始化
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _loadState();
    await _initializeNotifications();
  }

  /// 初始化通知系統
  Future<void> _initializeNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);

    // Android 建立通知頻道
    if (Platform.isAndroid) {
      await _createAndroidChannel();
    }
  }

  /// 建立 Android 通知頻道
  Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      PushConfig.channelId,
      PushConfig.channelName,
      description: '當你解鎖新區域時收到通知',
      importance: Importance.defaultImportance,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// 請求推播權限
  Future<bool> requestPermission() async {
    bool granted = false;

    if (Platform.isIOS) {
      granted = await _notifications
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(
                alert: true,
                badge: false,
                sound: true,
              ) ??
          false;
    } else if (Platform.isAndroid) {
      granted = await _notifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }

    _state = _state.copyWith(permissionGranted: granted);
    await _saveState();

    return granted;
  }

  /// 處理 Cell 解鎖觸發
  ///
  /// [cellId] - 解鎖的 Cell ID
  /// 返回是否成功發送推播
  Future<bool> handleCellUnlocked(String cellId) async {
    // 檢查權限
    if (!_state.permissionGranted) {
      return false;
    }

    // 檢查是否可以推播
    if (!_canPushNow()) {
      return false;
    }

    // 檢查安靜時段
    if (_isQuietHours()) {
      return false;
    }

    // 選擇訊息
    final message = _messageSelector.select();

    // 發送推播
    await _showNotification(message.body);

    // 記錄推播
    await _recordPush();

    return true;
  }

  /// 檢查是否可以推播
  bool _canPushNow() {
    final today = _getTodayString();

    // 檢查每日上限
    if (_state.lastPushDate == today) {
      if (_state.todayPushCount >= PushConfig.maxDailyPush) {
        return false;
      }
    }

    // 檢查最小間隔
    final minIntervalMs = PushConfig.minIntervalHours * 60 * 60 * 1000;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now - _state.lastPushTime < minIntervalMs) {
      return false;
    }

    return true;
  }

  /// 檢查是否在安靜時段
  bool _isQuietHours() {
    final hour = DateTime.now().hour;

    // 如果開始時間大於結束時間（跨日）
    if (PushConfig.quietHoursStart > PushConfig.quietHoursEnd) {
      return hour >= PushConfig.quietHoursStart ||
          hour < PushConfig.quietHoursEnd;
    }

    return hour >= PushConfig.quietHoursStart &&
        hour < PushConfig.quietHoursEnd;
  }

  /// 顯示通知
  Future<void> _showNotification(String body) async {
    const androidDetails = AndroidNotificationDetails(
      PushConfig.channelId,
      PushConfig.channelName,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      null, // 無標題
      body,
      details,
    );
  }

  /// 記錄推播
  Future<void> _recordPush() async {
    final today = _getTodayString();
    final now = DateTime.now().millisecondsSinceEpoch;

    int newCount;
    if (_state.lastPushDate != today) {
      newCount = 1;
    } else {
      newCount = _state.todayPushCount + 1;
    }

    _state = _state.copyWith(
      lastPushTime: now,
      lastPushDate: today,
      todayPushCount: newCount,
    );

    await _saveState();
  }

  /// 取得今天日期字串
  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 載入狀態
  Future<void> _loadState() async {
    final json = _prefs?.getString(_storageKey);
    if (json != null) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        _state = PushState.fromMap(map);
      } catch (e) {
        _state = PushState.empty;
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
    _state = PushState.empty;
    await _prefs?.remove(_storageKey);
    _messageSelector.resetRecentlyUsed();
  }
}
