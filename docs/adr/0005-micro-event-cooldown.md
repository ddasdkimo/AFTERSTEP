# ADR 0005: 微事件冷卻機制設計

## 狀態

已採納

## 背景

微事件是「偶然發現」的驚喜，需要控制觸發頻率以：
1. 避免「被刷」，維持稀有感
2. 不讓使用者在同一地點反覆觸發
3. 每日觸發次數合理

## 決策

採用三層冷卻機制：

### 1. Cell 冷卻（24 小時）
同一個 Cell 在 24 小時內只能觸發一次微事件。

### 2. 每日上限（3 次）
使用者每天最多觸發 3 次微事件。

### 3. 停留時間門檻（45 秒）
使用者需要在同一位置停留 45 秒才會觸發。

## 理由

1. **符合規格要求**：TECHNICAL_SPEC.md 明確指定這些參數
2. **防刷機制**：Cell 冷卻防止在同一地點反覆觸發
3. **稀有感**：每日 3 次限制讓微事件保持特別
4. **有意義的停留**：45 秒確保使用者真的「停下來」

## 實作細節

```dart
class CooldownManager {
  // Cell 冷卻記錄
  Map<String, DateTime> _cellCooldowns = {};

  // 每日計數
  int _dailyCount = 0;
  DateTime _lastResetDate;

  bool canTrigger(String cellId) {
    // 檢查每日上限
    if (_dailyCount >= 3) return false;

    // 檢查 Cell 冷卻
    final lastTrigger = _cellCooldowns[cellId];
    if (lastTrigger != null) {
      final elapsed = DateTime.now().difference(lastTrigger);
      if (elapsed.inHours < 24) return false;
    }

    return true;
  }
}
```

## 取捨

- **缺點**：使用者可能因為剛好觸發 3 次就不再嘗試停留
- **緩解**：不顯示任何計數或限制提示，使用者不知道具體規則
- **優點**：符合「不解釋玩法」原則

## 後果

- CooldownManager 負責所有冷卻邏輯
- 冷卻記錄持久化到 SharedPreferences
- 每日計數在 00:00 重置
