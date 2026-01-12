# ADR 0004: 本地儲存選擇 SQLite

## 狀態

已採納

## 背景

應用需要支援離線運作，需要選擇本地儲存方案來儲存：
1. Fog 解鎖點（UnlockPoint）
2. Cell 解鎖狀態
3. 微事件觸發記錄
4. 推播記錄

可選方案：
- **A: SharedPreferences**：簡單 key-value 儲存
- **B: SQLite (sqflite)**：關聯式資料庫
- **C: Hive**：NoSQL 物件儲存
- **D: Isar**：高效能 NoSQL 資料庫

## 決策

選擇 **SQLite (sqflite)** 作為本地儲存方案。

## 理由

1. **符合規格建議**：TECHNICAL_SPEC.md 建議使用 SQLite
2. **成熟穩定**：SQLite 是業界標準，跨平台支援完善
3. **查詢能力**：支援 SQL 查詢，方便進行空間範圍查詢
4. **資料完整性**：支援 transaction，確保資料一致性
5. **社群支援**：sqflite 是 Flutter 最常用的 SQLite 套件

## 資料表設計

```sql
-- Fog 解鎖點
CREATE TABLE unlock_points (
  id TEXT PRIMARY KEY,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  radius REAL NOT NULL,
  timestamp INTEGER NOT NULL,
  synced INTEGER DEFAULT 0
);

-- Cell 狀態
CREATE TABLE cells (
  cell_id TEXT PRIMARY KEY,
  unlocked INTEGER DEFAULT 0,
  unlocked_at INTEGER,
  last_activity INTEGER
);

-- 微事件記錄
CREATE TABLE micro_events (
  id TEXT PRIMARY KEY,
  cell_id TEXT NOT NULL,
  event_id TEXT NOT NULL,
  triggered_at INTEGER NOT NULL
);
```

## 取捨

- **缺點**：需要手動寫 SQL，不如 ORM 方便
- **緩解**：使用 StorageService 封裝所有資料庫操作
- **缺點**：Schema 變更需要寫 migration
- **緩解**：MVP 階段 Schema 較穩定，後續可加入 migration 機制

## 後果

- StorageService 作為唯一的資料庫存取點
- 所有模組透過 StorageService 進行本地儲存
- 支援批量寫入和 transaction
