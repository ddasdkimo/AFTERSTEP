import 'dart:math' as math;

/// 推播訊息定義
class PushMessage {
  const PushMessage({
    required this.id,
    required this.body,
    required this.weight,
  });

  final String id;
  final String body;
  final int weight;
}

/// 推播訊息文案庫
const List<PushMessage> pushMessages = [
  PushMessage(id: 'msg_1', body: '世界剛剛多亮了一點。', weight: 10),
  PushMessage(id: 'msg_2', body: '你今天走出了一段路。', weight: 10),
  PushMessage(id: 'msg_3', body: '新的地方被記住了。', weight: 8),
  PushMessage(id: 'msg_4', body: '又有一塊霧散開了。', weight: 8),
  PushMessage(id: 'msg_5', body: '地圖上多了一道光。', weight: 7),
  PushMessage(id: 'msg_6', body: '這裡，被你照亮了。', weight: 6),
  PushMessage(id: 'msg_7', body: '足跡延伸了一些。', weight: 7),
  PushMessage(id: 'msg_8', body: '世界又大了一點點。', weight: 8),
];

/// 訊息選擇器
class PushMessageSelector {
  PushMessageSelector({
    List<PushMessage>? messages,
    math.Random? random,
  })  : _messages = messages ?? pushMessages,
        _random = random ?? math.Random();

  final List<PushMessage> _messages;
  final math.Random _random;
  final List<String> _recentlyUsed = [];
  static const int _recentLimit = 3;

  /// 選擇訊息
  PushMessage select() {
    // 過濾掉最近使用的
    final available =
        _messages.where((m) => !_recentlyUsed.contains(m.id)).toList();
    final pool = available.isNotEmpty ? available : _messages;

    // 加權隨機選擇
    final totalWeight = pool.fold<int>(0, (sum, m) => sum + m.weight);
    var random = _random.nextDouble() * totalWeight;

    for (final message in pool) {
      random -= message.weight;
      if (random <= 0) {
        _recordUsage(message.id);
        return message;
      }
    }

    final selected = pool.last;
    _recordUsage(selected.id);
    return selected;
  }

  void _recordUsage(String id) {
    _recentlyUsed.add(id);
    if (_recentlyUsed.length > _recentLimit) {
      _recentlyUsed.removeAt(0);
    }
  }

  void resetRecentlyUsed() {
    _recentlyUsed.clear();
  }
}
