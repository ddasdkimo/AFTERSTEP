# ADR 0006: 紅點位置模糊化策略

## 狀態

已採納

## 背景

紅點代表「其他人曾在此存在」的痕跡，但不能精確顯示他人位置，以維護：
1. 隱私保護
2. 「不顯示他人」的核心原則
3. 神秘感的產品定位

## 決策

使用隨機偏移進行位置模糊化：
- 偏移距離：50-100 米
- 偏移方向：隨機 360 度

## 理由

1. **符合規格要求**：TECHNICAL_SPEC.md 明確指定 50-100m 偏移
2. **隱私保護**：無法從紅點位置推斷實際位置
3. **視覺效果**：紅點散布更自然，不會重疊在道路上
4. **可重複性**：使用 Cell ID 作為 seed 確保同一 Cell 偏移一致

## 實作細節

```dart
class PositionObfuscator {
  Offset obfuscate(double lat, double lng, String cellId) {
    // 使用 Cell ID 產生確定性隨機數
    final random = Random(cellId.hashCode);

    // 隨機距離 50-100m
    final distance = 50 + random.nextDouble() * 50;

    // 隨機方向 0-360 度
    final bearing = random.nextDouble() * 2 * pi;

    // 計算偏移後座標
    return _offsetCoordinate(lat, lng, distance, bearing);
  }
}
```

## 使用 Cell ID 作為 Seed 的原因

- **一致性**：同一 Cell 的紅點每次顯示位置相同
- **避免跳動**：重新載入頁面時紅點不會「跳到」新位置
- **可驗證**：方便測試和除錯

## 取捨

- **缺點**：偏移後可能落在「不合理」的位置（如建築物內）
- **緩解**：50-100m 偏移在城市環境中仍在合理範圍
- **後續改進**：可考慮使用道路資料進行「吸附」

## 後果

- PositionObfuscator 負責所有位置模糊
- 紅點真實位置不會傳送到客戶端
- 模糊後位置用於顯示，不用於計算
