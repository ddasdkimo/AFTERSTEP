# ADR 0001: Fog 渲染策略選擇 Circle Stamp

## 狀態

已採納

## 背景

Fog of War 是本應用的核心視覺元素，需要選擇一個適合的渲染策略來：
1. 支援即時解鎖效果
2. 維持良好的效能（60 FPS）
3. 支援離線狀態下的本地渲染

可選方案：
- **A: Tile-based（瓦片式）**：將地圖切分成固定大小的瓦片，逐一解鎖
- **B: Circle Stamp（圓形印章）**：在使用者位置繪製漸層圓形，使用 `destination-out` 混合模式擦除黑霧
- **C: Polygon Mask**：追蹤路徑並生成多邊形遮罩

## 決策

選擇 **Circle Stamp** 策略。

## 理由

1. **視覺效果最佳**：漸層圓形邊緣產生自然的「探索」感覺，符合產品定位
2. **實作簡單**：使用 Canvas API 的 `saveLayer` + `BlendMode.dstOut` 即可實現
3. **效能可控**：透過限制同時渲染的點數量（viewport culling）保持效能
4. **符合規格**：TECHNICAL_SPEC.md 明確指定 Circle Stamp 策略

## 取捨

- **缺點**：儲存空間較大（每個解鎖點都需儲存座標和半徑）
- **緩解**：使用 SQLite 本地儲存，並只同步必要資料到 Firebase

## 後果

- 每次位置更新生成一個 `UnlockPoint` 物件
- 渲染時遍歷所有 viewport 內的點進行繪製
- 大量點時需要實作空間索引（R-tree）優化查詢
