import 'dart:async';

import '../../core/config/constants.dart';
import '../../data/models/cell.dart';

/// Cell 快取
///
/// 提供 Cell 狀態的本地快取，減少資料庫和網路請求。
class CellCache {
  /// 建立 Cell 快取
  CellCache({
    int maxSize = CellConfig.cacheMaxCells,
    int ttl = CellConfig.cacheTtl,
  })  : _maxSize = maxSize,
        _ttl = ttl;

  final int _maxSize;
  final int _ttl;

  final Map<String, _CacheEntry<UserCellState>> _cache = {};

  /// 取得 Cell 狀態
  ///
  /// [cellId] - Cell ID
  /// 返回快取的 Cell 狀態，如果不存在或已過期則返回 null
  UserCellState? get(String cellId) {
    final entry = _cache[cellId];
    if (entry == null) return null;

    if (_isExpired(entry)) {
      _cache.remove(cellId);
      return null;
    }

    return entry.value;
  }

  /// 設定 Cell 狀態
  ///
  /// [cellId] - Cell ID
  /// [state] - Cell 狀態
  void set(String cellId, UserCellState state) {
    // 如果快取已滿，移除最舊的項目
    if (_cache.length >= _maxSize) {
      _evictOldest();
    }

    _cache[cellId] = _CacheEntry(
      value: state,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 批次取得 Cell 狀態
  ///
  /// [cellIds] - Cell ID 列表
  /// 返回 Map<cellId, state>，不存在的 Cell 不會包含在結果中
  Map<String, UserCellState> getAll(List<String> cellIds) {
    final result = <String, UserCellState>{};

    for (final cellId in cellIds) {
      final state = get(cellId);
      if (state != null) {
        result[cellId] = state;
      }
    }

    return result;
  }

  /// 批次設定 Cell 狀態
  ///
  /// [states] - Map<cellId, state>
  void setAll(Map<String, UserCellState> states) {
    for (final entry in states.entries) {
      set(entry.key, entry.value);
    }
  }

  /// 預載入 Cell 狀態
  ///
  /// [cells] - Cell 列表
  /// [loader] - 載入函數
  Future<void> preload(
    List<Cell> cells,
    Future<UserCellState?> Function(String cellId) loader,
  ) async {
    // 找出未快取的 Cell
    final uncachedIds = cells
        .map((c) => c.cellId)
        .where((id) => !_cache.containsKey(id) || _isExpired(_cache[id]!))
        .toList();

    // 並行載入
    final futures = uncachedIds.map((id) async {
      final state = await loader(id);
      if (state != null) {
        set(id, state);
      }
    });

    await Future.wait(futures);
  }

  /// 移除指定 Cell 的快取
  void remove(String cellId) {
    _cache.remove(cellId);
  }

  /// 清空快取
  void clear() {
    _cache.clear();
  }

  /// 取得快取大小
  int get size => _cache.length;

  /// 檢查是否包含指定 Cell
  bool contains(String cellId) {
    final entry = _cache[cellId];
    if (entry == null) return false;
    return !_isExpired(entry);
  }

  /// 檢查項目是否已過期
  bool _isExpired(_CacheEntry entry) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - entry.timestamp > _ttl;
  }

  /// 移除最舊的快取項目
  void _evictOldest() {
    if (_cache.isEmpty) return;

    String? oldestKey;
    int oldestTime = DateTime.now().millisecondsSinceEpoch;

    for (final entry in _cache.entries) {
      if (entry.value.timestamp < oldestTime) {
        oldestTime = entry.value.timestamp;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      _cache.remove(oldestKey);
    }
  }

  /// 清理過期項目
  void cleanup() {
    final expiredKeys = _cache.entries
        .where((e) => _isExpired(e.value))
        .map((e) => e.key)
        .toList();

    for (final key in expiredKeys) {
      _cache.remove(key);
    }
  }
}

/// 快取項目
class _CacheEntry<T> {
  const _CacheEntry({
    required this.value,
    required this.timestamp,
  });

  final T value;
  final int timestamp;
}
