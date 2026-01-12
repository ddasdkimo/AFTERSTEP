# Architecture Decision Records (ADR)

本目錄包含專案的架構決策記錄。每個 ADR 記錄一個重要的技術決策，包含背景、決策理由和後果。

## ADR 列表

| 編號 | 標題 | 狀態 |
|------|------|------|
| [0001](0001-fog-rendering-strategy.md) | Fog 渲染策略選擇 Circle Stamp | 已採納 |
| [0002](0002-cell-size-decision.md) | Cell 網格尺寸選擇 200 米 | 已採納 |
| [0003](0003-red-dot-decay-algorithm.md) | 紅點強度衰減使用指數衰減 | 已採納 |
| [0004](0004-local-storage-choice.md) | 本地儲存選擇 SQLite | 已採納 |
| [0005](0005-micro-event-cooldown.md) | 微事件冷卻機制設計 | 已採納 |
| [0006](0006-position-obfuscation.md) | 紅點位置模糊化策略 | 已採納 |

## ADR 格式

每個 ADR 使用以下格式：

```markdown
# ADR XXXX: 標題

## 狀態
已提議 / 已採納 / 已棄用 / 已取代

## 背景
描述決策的背景和需要解決的問題。

## 決策
描述採取的決策。

## 理由
解釋為什麼做出這個決策。

## 取捨
說明這個決策的優缺點和權衡。

## 後果
描述這個決策帶來的影響。
```

## 新增 ADR

1. 複製模板到新檔案
2. 編號遞增（如 0007）
3. 填寫所有欄位
4. 更新本 README 的列表
