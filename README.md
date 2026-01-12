# AFTERSTEP Fog - 現實世界 Fog

> 使用者透過步行在現實世界中解鎖地圖霧區，並偶爾看見其他人曾存在過的模糊痕跡。

## 專案概述

AFTERSTEP Fog 是一款 Flutter 跨平台行動應用程式，讓使用者透過實際步行來「解鎖」覆蓋在地圖上的迷霧。核心設計原則：

- **不解釋玩法**：無教學、無提示、無任務
- **不顯示他人**：只有模糊的「存在痕跡」（紅點系統）
- **不做目標導向**：無成就、無排行榜、無獎勵
- **不可被刷**：只有步行有效，有冷卻機制

## 技術架構

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              Client (App)                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐   │
│  │ LocationService │────>│   CellService   │────>│   FogManager    │   │
│  │  (GPS 追蹤)      │     │  (網格系統)      │     │  (霧解鎖)       │   │
│  └────────┬────────┘     └────────┬────────┘     └────────┬────────┘   │
│           │                       │                       │             │
│           │              ┌────────▼────────┐              │             │
│           │              │  RedDotService  │              │             │
│           │              │   (紅點系統)     │              │             │
│           │              └────────┬────────┘              │             │
│           │                       │                       │             │
│           ▼                       ▼                       ▼             │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐   │
│  │ MicroEventSvc   │     │   PushService   │     │   FogRenderer   │   │
│  │  (微事件)        │     │    (推播)        │     │   (渲染)        │   │
│  └─────────────────┘     └─────────────────┘     └─────────────────┘   │
│                                                                          │
└──────────────────────────────────┬───────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           Firebase (Server)                              │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐   │
│  │    Firestore    │     │   Cloud Msg     │     │    Auth         │   │
│  │  (Cell 活動)     │     │   (推播)        │     │   (匿名登入)     │   │
│  └─────────────────┘     └─────────────────┘     └─────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

## 功能模組

### 1. GPS 追蹤與速度判定 (LocationService)

- 即時 GPS 追蹤
- 智慧速度判定 (0.6-1.8 m/s 為有效步行)
- 漂移過濾
- 停留偵測

### 2. Cell 網格系統 (CellService)

- 200m 網格劃分
- 座標 ↔ Cell ID 轉換
- 鄰近 Cell 查詢
- Firestore 活動記錄

### 3. Fog 解鎖系統 (FogManager)

- Circle Stamp 渲染策略
- 漸層圓形擦除黑霧
- SQLite 本地持久化
- Firebase 雲端同步

### 4. 紅點系統 (RedDotService)

- 指數衰減顯示 (τ=5 天)
- 位置模糊化 (50-100m 隨機偏移)
- 脈動動畫效果
- 只顯示在已解鎖區域

### 5. 微事件系統 (MicroEventService)

- 25% 觸發機率
- 45 秒停留觸發
- Cell 冷卻 24 小時
- 每日上限 3 次
- 詩意文案庫

### 6. 推播系統 (PushService)

- 每日最多 1 則
- 首次解鎖觸發
- 安靜時段 (22:00-08:00)
- 本地推播實作

## 專案結構

```
lib/
├── main.dart                    # 應用程式入口
├── core/
│   ├── config/constants.dart    # 全域設定參數
│   ├── app_state.dart          # 應用程式狀態管理
│   ├── utils/geo_utils.dart    # 地理計算工具
│   └── services/storage_service.dart  # SQLite 儲存服務
│
├── features/
│   ├── location/               # GPS 追蹤模組
│   │   ├── location_service.dart
│   │   ├── speed_calculator.dart
│   │   ├── drift_filter.dart
│   │   └── stay_detector.dart
│   │
│   ├── cell/                   # Cell 網格模組
│   │   ├── cell_service.dart
│   │   ├── geo_encoder.dart
│   │   ├── cell_cache.dart
│   │   └── cell_firestore.dart
│   │
│   ├── fog/                    # Fog 解鎖模組
│   │   ├── fog_manager.dart
│   │   ├── fog_storage.dart
│   │   └── fog_sync_service.dart
│   │
│   ├── red_dot/                # 紅點系統模組
│   │   ├── red_dot_service.dart
│   │   ├── intensity_calculator.dart
│   │   └── position_obfuscator.dart
│   │
│   ├── micro_event/            # 微事件模組
│   │   ├── micro_event_service.dart
│   │   ├── cooldown_manager.dart
│   │   └── text_selector.dart
│   │
│   └── push/                   # 推播模組
│       ├── push_service.dart
│       └── push_messages.dart
│
├── ui/
│   ├── screens/map_screen.dart # 主畫面
│   ├── widgets/
│   │   ├── fog_layer.dart
│   │   ├── red_dot_layer.dart
│   │   └── micro_event_overlay.dart
│   └── painters/
│       ├── fog_painter.dart
│       └── red_dot_painter.dart
│
└── data/
    └── models/                 # 資料模型
        ├── location_point.dart
        ├── cell.dart
        ├── unlock_point.dart
        ├── red_dot.dart
        └── micro_event.dart
```

## 環境建置

### 系統需求

- Flutter SDK 3.19+
- Dart 3.3+
- Xcode 15+ (iOS)
- Android Studio (Android)
- Firebase CLI

### 安裝步驟

1. **克隆專案**

```bash
git clone <repository-url>
cd afterstep_fog
```

2. **安裝 Flutter 依賴**

```bash
flutter pub get
```

3. **配置 Firebase**

```bash
# 安裝 Firebase CLI
npm install -g firebase-tools

# 登入 Firebase
firebase login

# 初始化 FlutterFire
dart pub global activate flutterfire_cli
flutterfire configure
```

4. **iOS 配置**

確保 `ios/Runner/Info.plist` 包含以下權限：

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>需要您的位置來解鎖地圖</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>背景持續追蹤以記錄您的步行軌跡</string>
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
</array>
```

5. **執行應用程式**

```bash
# iOS 模擬器
flutter run -d ios

# Android 模擬器
flutter run -d android

# 真機 (需連接設備)
flutter run
```

## 測試

### 執行所有測試

```bash
flutter test
```

### 測試覆蓋率

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### 測試檔案結構

```
test/
├── core/utils/geo_utils_test.dart
├── data/models/
│   ├── cell_test.dart
│   ├── location_point_test.dart
│   ├── micro_event_test.dart
│   ├── red_dot_test.dart
│   └── unlock_point_test.dart
├── features/
│   ├── cell/
│   │   ├── cell_cache_test.dart
│   │   └── geo_encoder_test.dart
│   ├── fog/fog_manager_test.dart
│   ├── location/
│   │   ├── drift_filter_test.dart
│   │   ├── speed_calculator_test.dart
│   │   └── stay_detector_test.dart
│   ├── micro_event/
│   │   ├── cooldown_manager_test.dart
│   │   └── text_selector_test.dart
│   ├── push/push_messages_test.dart
│   └── red_dot/
│       ├── intensity_calculator_test.dart
│       └── position_obfuscator_test.dart
└── widget_test.dart
```

## 主要依賴

| 套件 | 版本 | 用途 |
|------|------|------|
| flutter_map | ^7.0.2 | 地圖渲染 |
| latlong2 | ^0.9.1 | 地理座標處理 |
| geolocator | ^13.0.2 | GPS 定位 |
| sqflite | ^2.4.1 | 本地 SQLite 儲存 |
| firebase_core | ^3.9.0 | Firebase 核心 |
| firebase_auth | ^5.4.0 | Firebase 認證 |
| cloud_firestore | ^5.6.1 | Firestore 資料庫 |
| flutter_local_notifications | ^18.0.1 | 本地推播 |
| rxdart | ^0.28.0 | 響應式程式設計 |
| provider | ^6.1.2 | 狀態管理 |
| shared_preferences | ^2.3.4 | 輕量本地儲存 |

## 核心參數配置

所有核心參數位於 `lib/core/config/constants.dart`：

```dart
// GPS 設定
class GpsConfig {
  static const double speedMin = 0.6;      // 最低有效速度 (m/s)
  static const double speedMax = 1.8;      // 最高有效速度 (m/s)
  static const double speedCutoff = 2.5;   // 完全無效速度
  static const double accuracyThreshold = 20.0;  // 精度門檻 (m)
}

// Cell 設定
class CellConfig {
  static const int cellSize = 200;         // Cell 尺寸 (m)
}

// 紅點設定
class RedDotConfig {
  static const double decayTauDays = 5.0;  // 衰減時間常數 (天)
  static const double intensityThreshold = 0.1;  // 顯示門檻
}

// 微事件設定
class MicroEventConfig {
  static const int triggerStayDuration = 45;     // 觸發停留時間 (秒)
  static const double triggerProbability = 0.25; // 觸發機率
  static const int dailyMaxEvents = 3;           // 每日上限
}
```

## Firebase 資料結構

```
firestore/
├── cells/                          # 全域 Cell 活動
│   └── {cell_id}/
│       └── last_activity_time: Timestamp
│
└── users/
    └── {user_id}/
        ├── cells/                  # 使用者 Cell 狀態
        │   └── {cell_id}/
        │       ├── unlocked: boolean
        │       └── unlocked_at: Timestamp
        │
        └── fog/                    # 使用者 Fog 資料
            └── {point_id}/
                ├── latitude: number
                ├── longitude: number
                ├── radius: number
                └── timestamp: Timestamp
```

## 開發指南

### 新增微事件文案

編輯 `lib/features/micro_event/micro_event_texts.dart`：

```dart
const microEventTexts = [
  MicroEventDefinition(
    id: 'new_1',
    text: '你的新文案。',
    category: EventCategory.presence,
    weight: 10,
  ),
  // ...
];
```

### 調整速度判定

修改 `lib/core/config/constants.dart` 中的 `GpsConfig`：

```dart
class GpsConfig {
  static const double speedMin = 0.5;  // 調低最低速度
  static const double speedMax = 2.0;  // 調高最高速度
  // ...
}
```

### 自訂 Fog 渲染效果

修改 `lib/ui/painters/fog_painter.dart` 中的漸層參數：

```dart
gradient.addColorStop(0, 'rgba(255, 255, 255, 1)');
gradient.addColorStop(0.7, 'rgba(255, 255, 255, 1)');  // 調整邊緣模糊
gradient.addColorStop(1, 'rgba(255, 255, 255, 0)');
```

## Firebase Emulator 操作

### 啟動 Emulator

```bash
# 安裝 Firebase CLI (如未安裝)
npm install -g firebase-tools

# 啟動所有 emulator
firebase emulators:start

# 或只啟動特定服務
firebase emulators:start --only firestore,auth
```

### Emulator UI

- Emulator UI: http://localhost:4000
- Firestore: http://localhost:8080
- Auth: http://localhost:9099

### 在 Flutter 中連接 Emulator

應用程式會自動偵測是否在 debug 模式，並連接本地 emulator：

```dart
// 在 main.dart 中已配置
if (kDebugMode) {
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
}
```

### 匯出/匯入 Emulator 資料

```bash
# 匯出資料
firebase emulators:export ./emulator-data

# 使用已儲存的資料啟動
firebase emulators:start --import=./emulator-data
```

## iOS 真機測試步驟

### 前置需求

1. Apple Developer 帳號（免費或付費）
2. Xcode 15+
3. 實體 iOS 裝置（iOS 13.0+）
4. USB 線連接或相同 WiFi 網路

### 步驟

1. **開啟 Xcode 專案**

```bash
open ios/Runner.xcworkspace
```

2. **設定 Signing**

- 在 Xcode 左側選擇 Runner 專案
- 選擇 Signing & Capabilities 標籤
- 選擇你的 Team
- 確認 Bundle Identifier 是唯一的

3. **信任開發者憑證** (首次安裝)

在 iOS 裝置上：
- 設定 > 一般 > VPN 與裝置管理
- 點選你的開發者 App
- 點選「信任」

4. **執行到真機**

```bash
# 列出可用裝置
flutter devices

# 執行到特定裝置
flutter run -d <device-id>

# 或建置後安裝
flutter build ios
```

5. **背景定位測試**

真機測試背景定位時：
- 確保已授予「永遠允許」位置權限
- 進入背景後，檢查 Console 日誌確認位置更新
- 使用 Xcode Instruments 監控電池使用

### 常見真機問題

| 問題 | 解決方案 |
|------|----------|
| 無法安裝到裝置 | 檢查 Bundle ID 是否衝突、重新 trust 開發者 |
| GPS 無法取得 | 確認位置權限、檢查 Info.plist 設定 |
| Firebase 連線失敗 | 確認 GoogleService-Info.plist 已正確配置 |

## 常見問題排除

### 建置問題

**Q: `pod install` 失敗**

```bash
cd ios
pod deintegrate
pod cache clean --all
pod install --repo-update
```

**Q: Flutter 版本不相容**

```bash
flutter upgrade
flutter pub upgrade
```

**Q: Xcode 建置失敗**

1. 清理建置資料夾：Product > Clean Build Folder
2. 刪除 DerivedData：`rm -rf ~/Library/Developer/Xcode/DerivedData`
3. 重新執行 `pod install`

### 執行時問題

**Q: 位置權限被拒絕**

- 確認 Info.plist 有正確的權限說明
- 在設定中手動開啟位置權限
- 卸載並重新安裝 App

**Q: Fog 沒有解鎖**

檢查以下條件：
1. GPS 精度 < 20m
2. 步行速度在 0.6-1.8 m/s 之間
3. 沒有被漂移過濾器過濾

使用 debug overlay 檢視即時數據：

```dart
// 在 MapScreen 中啟用 debug overlay
showDebugOverlay: true,
```

**Q: 紅點沒有顯示**

紅點只顯示在：
1. 已解鎖的區域內
2. 最近 5 天內有其他人活動的 Cell
3. 強度 > 0.1（衰減後仍可見）

**Q: 微事件沒有觸發**

微事件需要滿足：
1. 在同一位置停留 45 秒
2. 該 Cell 24 小時內未觸發過
3. 當日觸發次數 < 3
4. 25% 機率判定通過

### Firebase 問題

**Q: Firestore 連線失敗**

```bash
# 檢查 Firebase 配置
cat ios/Runner/GoogleService-Info.plist

# 確認 firebase_options.dart 存在
ls lib/firebase_options.dart
```

**Q: 匿名登入失敗**

1. 確認 Firebase Console 已啟用匿名登入
2. 檢查網路連線
3. 查看 Console 日誌獲取詳細錯誤

### 效能問題

**Q: App 卡頓**

- 減少同時顯示的 Fog 點數量
- 使用 `RepaintBoundary` 隔離渲染
- 檢查是否有記憶體洩漏

**Q: 電池消耗過快**

- 調整 GPS 更新頻率
- 確認背景定位使用 `significant-change` 模式
- 減少 Firestore 同步頻率

## 授權

本專案為私有專案，保留所有權利。

## 聯絡

如有問題，請聯繫專案維護者。
