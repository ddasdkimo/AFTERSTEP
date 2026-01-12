# 《現實世界 Fog》完整技術規格文件

> MVP v0.1 | 最後更新：2026-01-12

---

## 目錄

1. [產品概覽](#1-產品概覽)
2. [系統架構](#2-系統架構)
3. [模組 1：GPS 追蹤與速度判定](#3-模組-1gps-追蹤與速度判定)
4. [模組 2：Fog 解鎖與渲染](#4-模組-2fog-解鎖與渲染)
5. [模組 3：Cell 網格系統](#5-模組-3cell-網格系統)
6. [模組 4：紅點系統](#6-模組-4紅點系統)
7. [模組 5：微事件系統](#7-模組-5微事件系統)
8. [模組 6：推播系統](#8-模組-6推播系統)
9. [Firebase 設定](#9-firebase-設定)
10. [開發建議](#10-開發建議)

---

## 1. 產品概覽

### 1.1 一句話定義

> 使用者透過步行在現實世界中解鎖地圖霧區，並偶爾看見其他人曾存在過的模糊痕跡。

### 1.2 核心原則（不可違反）

| 原則 | 說明 |
|------|------|
| 不解釋玩法 | 無教學、無提示、無任務 |
| 不顯示他人 | 只有模糊的「存在痕跡」 |
| 不做目標導向 | 無成就、無排行榜、無獎勵 |
| 不可被刷 | 只有步行有效，有冷卻機制 |

### 1.3 MVP 範圍

**本版本一定要有：**
- Fog of War 解鎖
- 步行速度判定
- 紅點（模糊、常見）
- 單一型態微事件（文字）
- 極簡推播（一天一次）

**本版本明確不做：**
- 社交 / 好友
- 任務 / 成就
- 排行榜
- 商店 / POI
- 教學流程

### 1.4 技術棧

| 項目 | 選擇 |
|------|------|
| 平台 | 跨平台（Flutter） |
| 地圖 | 全黑自繪（Canvas） |
| Fog 儲存 | Firebase + 本地快取 |
| 後端 | Firebase (Firestore + Functions) |
| 離線 | 支援 GPS 追蹤離線運作 |

---

## 2. 系統架構

### 2.1 整體架構圖

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              Client (App)                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐   │
│  │ LocationService │────▶│   CellService   │────▶│   FogManager    │   │
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
│                                                                          │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐   │
│  │    Firestore    │     │   Cloud Msg     │     │    Auth         │   │
│  │  (Cell 活動)     │     │   (推播)        │     │   (匿名登入)     │   │
│  └─────────────────┘     └─────────────────┘     └─────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 資料流概覽

```
GPS 位置更新
    │
    ▼
┌─────────────┐
│ 速度判定    │ ─── 太快/太慢 → 忽略
└─────┬───────┘
      │ 有效步行
      ▼
┌─────────────┐     ┌─────────────┐
│ Cell 判定   │────▶│ 記錄活動    │ → Firestore
└─────┬───────┘     └─────────────┘
      │
      ▼
┌─────────────┐     ┌─────────────┐
│ Fog 解鎖    │────▶│ 檢查首次    │ → 推播
└─────┬───────┘     └─────────────┘
      │
      ▼
┌─────────────┐     ┌─────────────┐
│ 停留偵測    │────▶│ 微事件判定  │ → 文字浮現
└─────────────┘     └─────────────┘
```

---

## 3. 模組 1：GPS 追蹤與速度判定

### 3.1 架構

```
┌─────────────────────────────────────────────────────┐
│                   LocationService                    │
├─────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────┐ │
│  │ GPS Provider│───▶│ Filter Layer│───▶│ Output  │ │
│  │  (Raw)      │    │  (Validate) │    │ Stream  │ │
│  └─────────────┘    └─────────────┘    └─────────┘ │
│         │                  │                 │      │
│         ▼                  ▼                 ▼      │
│   [原始座標]         [速度判定]        [有效位置]   │
│                      [漂移過濾]        [解鎖事件]   │
└─────────────────────────────────────────────────────┘
```

### 3.2 資料結構

```typescript
// 單一定位點
interface LocationPoint {
  latitude: number;          // 緯度
  longitude: number;         // 經度
  accuracy: number;          // 精度（公尺）
  timestamp: number;         // Unix timestamp (ms)
  altitude?: number;         // 海拔（可選）
  speed?: number;            // 系統回報速度 m/s（不可信，僅參考）
}

// 處理後位置
interface ProcessedLocation {
  point: LocationPoint;
  calculatedSpeed: number;   // 自行計算的速度 m/s
  movementState: MovementState;
  isValid: boolean;          // 是否用於 Fog 解鎖
  distanceFromLast: number;  // 與上一點距離（公尺）
}

enum MovementState {
  STATIONARY = 'stationary',   // 靜止/漂移
  WALKING = 'walking',         // 有效步行
  FAST_WALKING = 'fast_walking', // 快走（效率遞減）
  TOO_FAST = 'too_fast'        // 騎車/開車（無效）
}

// 停留事件
interface StayEvent {
  centerLat: number;
  centerLng: number;
  startTime: number;
  duration: number;          // 秒
  radius: number;            // 停留範圍半徑
}
```

### 3.3 核心參數

```typescript
const GPS_CONFIG = {
  // 取樣設定
  INTERVAL_FOREGROUND: 3000,    // 前景取樣間隔 3 秒
  INTERVAL_BACKGROUND: 5000,    // 背景取樣間隔 5 秒

  // 精度過濾
  ACCURACY_THRESHOLD: 20,       // 精度 > 20m 視為無效

  // 速度判定 (m/s)
  SPEED_MIN: 0.6,               // 低於此為靜止
  SPEED_OPTIMAL: 1.2,           // 最佳步行速度
  SPEED_MAX: 1.8,               // 高於此開始遞減
  SPEED_CUTOFF: 2.5,            // 高於此完全無效

  // 漂移過濾
  DRIFT_THRESHOLD: 3,           // 靜止時 > 3m 移動視為漂移
  DRIFT_TIME_WINDOW: 10000,     // 10 秒內判定

  // 停留判定
  STAY_RADIUS: 15,              // 停留判定半徑 15m
  STAY_MIN_DURATION: 45,        // 最短停留時間 45 秒

  // 解鎖半徑
  UNLOCK_RADIUS_INSTANT: 15,    // 即時解鎖半徑
  UNLOCK_RADIUS_STAY: 40,       // 停留擴散半徑
};
```

### 3.4 速度計算

#### Haversine 距離公式

```typescript
function haversineDistance(
  lat1: number, lng1: number,
  lat2: number, lng2: number
): number {
  const R = 6371000; // 地球半徑（公尺）
  const φ1 = lat1 * Math.PI / 180;
  const φ2 = lat2 * Math.PI / 180;
  const Δφ = (lat2 - lat1) * Math.PI / 180;
  const Δλ = (lng2 - lng1) * Math.PI / 180;

  const a = Math.sin(Δφ/2) ** 2 +
            Math.cos(φ1) * Math.cos(φ2) *
            Math.sin(Δλ/2) ** 2;

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));

  return R * c;
}
```

#### 速度計算器

```typescript
class SpeedCalculator {
  private buffer: LocationPoint[] = [];
  private readonly BUFFER_SIZE = 5;

  calculate(current: LocationPoint, previous: LocationPoint): number {
    const distance = haversineDistance(
      previous.latitude, previous.longitude,
      current.latitude, current.longitude
    );
    const timeDelta = (current.timestamp - previous.timestamp) / 1000;

    if (timeDelta <= 0) return 0;

    const instantSpeed = distance / timeDelta;

    // 加入 buffer 做移動平均
    this.buffer.push(current);
    if (this.buffer.length > this.BUFFER_SIZE) {
      this.buffer.shift();
    }

    return this.getSmoothedSpeed(instantSpeed);
  }

  private getSmoothedSpeed(currentSpeed: number): number {
    // 移動平均，過濾瞬間雜訊
    return currentSpeed;
  }
}
```

### 3.5 移動狀態判定

```typescript
function determineMovementState(speed: number): MovementState {
  const { SPEED_MIN, SPEED_MAX, SPEED_CUTOFF } = GPS_CONFIG;

  if (speed < SPEED_MIN) {
    return MovementState.STATIONARY;
  }
  if (speed <= SPEED_MAX) {
    return MovementState.WALKING;
  }
  if (speed <= SPEED_CUTOFF) {
    return MovementState.FAST_WALKING;
  }
  return MovementState.TOO_FAST;
}

function getUnlockEfficiency(state: MovementState, speed: number): number {
  switch (state) {
    case MovementState.STATIONARY:
      return 0;

    case MovementState.WALKING:
      return 1.0;  // 100%

    case MovementState.FAST_WALKING:
      // 線性遞減：1.8 → 2.5 m/s 對應 100% → 0%
      const ratio = (speed - GPS_CONFIG.SPEED_MAX) /
                    (GPS_CONFIG.SPEED_CUTOFF - GPS_CONFIG.SPEED_MAX);
      return Math.max(0, 1 - ratio);

    case MovementState.TOO_FAST:
      return 0;
  }
}
```

### 3.6 漂移過濾

```typescript
class DriftFilter {
  private stationaryCenter: LocationPoint | null = null;
  private stationaryStartTime: number = 0;

  process(point: LocationPoint, state: MovementState): boolean {
    if (state !== MovementState.STATIONARY) {
      this.stationaryCenter = null;
      return true;
    }

    if (!this.stationaryCenter) {
      this.stationaryCenter = point;
      this.stationaryStartTime = point.timestamp;
      return true;
    }

    const distance = haversineDistance(
      this.stationaryCenter.latitude,
      this.stationaryCenter.longitude,
      point.latitude,
      point.longitude
    );

    if (distance > GPS_CONFIG.DRIFT_THRESHOLD) {
      const elapsed = point.timestamp - this.stationaryStartTime;
      if (elapsed < GPS_CONFIG.DRIFT_TIME_WINDOW) {
        return false; // 短時間內大距離 = 漂移
      }
      this.stationaryCenter = null;
      return true;
    }

    return true;
  }
}
```

### 3.7 停留偵測

```typescript
class StayDetector {
  private points: LocationPoint[] = [];
  private currentStay: StayEvent | null = null;

  process(point: LocationPoint): StayEvent | null {
    this.points.push(point);
    this.pruneOldPoints(point.timestamp);

    const center = this.calculateCenter();
    const allWithinRadius = this.points.every(p =>
      haversineDistance(center.lat, center.lng, p.latitude, p.longitude)
      <= GPS_CONFIG.STAY_RADIUS
    );

    if (!allWithinRadius) {
      const completedStay = this.currentStay;
      this.currentStay = null;
      this.points = [point];
      return completedStay;
    }

    const duration = (point.timestamp - this.points[0].timestamp) / 1000;

    if (duration >= GPS_CONFIG.STAY_MIN_DURATION) {
      if (!this.currentStay) {
        this.currentStay = {
          centerLat: center.lat,
          centerLng: center.lng,
          startTime: this.points[0].timestamp,
          duration: duration,
          radius: GPS_CONFIG.STAY_RADIUS
        };
      } else {
        this.currentStay.duration = duration;
      }
    }

    return null;
  }

  private pruneOldPoints(now: number) {
    const cutoff = now - 120000;
    this.points = this.points.filter(p => p.timestamp > cutoff);
  }

  private calculateCenter() {
    const lat = this.points.reduce((s, p) => s + p.latitude, 0) / this.points.length;
    const lng = this.points.reduce((s, p) => s + p.longitude, 0) / this.points.length;
    return { lat, lng };
  }
}
```

### 3.8 主服務

```typescript
class LocationService {
  private speedCalculator = new SpeedCalculator();
  private driftFilter = new DriftFilter();
  private stayDetector = new StayDetector();
  private lastPoint: LocationPoint | null = null;

  readonly validLocations$ = new Subject<ProcessedLocation>();
  readonly stayEvents$ = new Subject<StayEvent>();

  processRawLocation(raw: LocationPoint): void {
    // 1. 精度過濾
    if (raw.accuracy > GPS_CONFIG.ACCURACY_THRESHOLD) {
      return;
    }

    // 2. 計算速度
    let speed = 0;
    let distance = 0;
    if (this.lastPoint) {
      distance = haversineDistance(
        this.lastPoint.latitude, this.lastPoint.longitude,
        raw.latitude, raw.longitude
      );
      speed = this.speedCalculator.calculate(raw, this.lastPoint);
    }

    // 3. 判定移動狀態
    const state = determineMovementState(speed);

    // 4. 漂移過濾
    const isValid = this.driftFilter.process(raw, state);

    // 5. 停留偵測
    const completedStay = this.stayDetector.process(raw);
    if (completedStay) {
      this.stayEvents$.next(completedStay);
    }

    // 6. 輸出
    const processed: ProcessedLocation = {
      point: raw,
      calculatedSpeed: speed,
      movementState: state,
      isValid: isValid && state !== MovementState.TOO_FAST,
      distanceFromLast: distance
    };

    if (processed.isValid) {
      this.validLocations$.next(processed);
    }

    this.lastPoint = raw;
  }
}
```

### 3.9 平台設定

#### Flutter 依賴

```yaml
dependencies:
  geolocator: ^10.0.0
  flutter_background_service: ^5.0.0
```

#### iOS (Info.plist)

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

#### Android (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
```

### 3.10 電量優化

| 情境 | 取樣間隔 | 精度模式 |
|------|----------|----------|
| 前景 + 移動中 | 3 秒 | High |
| 前景 + 靜止 | 10 秒 | Balanced |
| 背景 + 移動中 | 5 秒 | High |
| 背景 + 靜止 | 30 秒 | Low |
| 完全靜止 > 5 分鐘 | 60 秒 | Low |

---

## 4. 模組 2：Fog 解鎖與渲染

### 4.1 架構

```
┌──────────────────────────────────────────────────────────────────┐
│                        FogSystem                                  │
├──────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐  │
│  │ FogStorage  │◄──▶│ FogManager  │───▶│    FogRenderer      │  │
│  │ (持久化)    │    │ (狀態管理)   │    │   (Canvas 繪製)     │  │
│  └─────────────┘    └─────────────┘    └─────────────────────┘  │
│         │                  ▲                      │              │
│         ▼                  │                      ▼              │
│   [本地 SQLite]      [LocationService]     [黑色遮罩層]         │
│   [Firebase Sync]    [CellService]         [解鎖動畫]           │
└──────────────────────────────────────────────────────────────────┘
```

### 4.2 渲染策略

**採用方案**：Circle Stamp（圓形印章）
- 每個解鎖點 = 一個漸層圓
- 使用 `destination-out` 混合模式「擦除」黑霧

| 方案 | 優點 | 缺點 | 適用性 |
|------|------|------|--------|
| Tile-based Mask | 記憶體可控 | 邊緣生硬 | ❌ |
| Vector Path | 平滑、精確 | 複雜度高 | ⚠️ |
| **Circle Stamp** | 簡單、自然 | 需合併處理 | ✅ 推薦 |

### 4.3 核心參數

```typescript
const FOG_CONFIG = {
  // 解鎖半徑
  UNLOCK_RADIUS_INSTANT: 15,      // 即時解鎖半徑（公尺）
  UNLOCK_RADIUS_STAY: 40,         // 停留擴散半徑（公尺）

  // 渲染設定
  FOG_COLOR: 'rgba(15, 15, 20, 1)',  // 霧的顏色（近黑）
  FOG_EDGE_BLUR: 0.3,                // 邊緣模糊比例 (0-1)

  // 效能設定
  POINT_MERGE_DISTANCE: 5,        // 合併距離小於 5m 的點
  MAX_POINTS_IN_MEMORY: 10000,    // 記憶體最大點數
  TILE_SIZE: 512,                 // 離屏 Canvas Tile 尺寸

  // 動畫
  UNLOCK_ANIMATION_DURATION: 300, // 解鎖動畫時長（ms）
  STAY_EXPAND_DURATION: 2000,     // 停留擴散動畫時長（ms）

  // 同步
  SYNC_DEBOUNCE: 5000,            // 同步防抖（ms）
  SYNC_BATCH_SIZE: 100,           // 批次同步點數
};
```

### 4.4 資料結構

```typescript
// 解鎖點
interface UnlockPoint {
  id: string;
  latitude: number;
  longitude: number;
  radius: number;
  timestamp: number;
  type: UnlockType;
}

enum UnlockType {
  WALK = 'walk',
  STAY = 'stay',
}

// 軌跡段
interface UnlockPath {
  id: string;
  points: Array<{
    latitude: number;
    longitude: number;
  }>;
  width: number;
  timestamp: number;
}

// 完整狀態
interface FogState {
  points: UnlockPoint[];
  paths: UnlockPath[];
  totalUnlockedArea: number;
  lastSyncTime: number;
}
```

### 4.5 座標轉換

```typescript
class FogCoordinateSystem {
  private mapView: MapView;

  // 經緯度 → 螢幕像素
  geoToScreen(lat: number, lng: number): { x: number; y: number } {
    const zoom = this.mapView.zoom;
    const scale = Math.pow(2, zoom) * 256;

    const x = (lng + 180) / 360 * scale;
    const latRad = lat * Math.PI / 180;
    const y = (1 - Math.log(Math.tan(latRad) + 1 / Math.cos(latRad)) / Math.PI) / 2 * scale;

    return this.mapView.worldToScreen(x, y);
  }

  // 公尺 → 像素
  metersToPixels(meters: number, latitude: number): number {
    const zoom = this.mapView.zoom;
    const metersPerPixel = 156543.03392 * Math.cos(latitude * Math.PI / 180) / Math.pow(2, zoom);
    return meters / metersPerPixel;
  }
}
```

### 4.6 渲染器

```typescript
class FogRenderer {
  private fogCanvas: HTMLCanvasElement;
  private fogCtx: CanvasRenderingContext2D;
  private coordSystem: FogCoordinateSystem;

  render(state: FogState): void {
    const { width, height } = this.fogCanvas;
    const ctx = this.fogCtx;

    // 1. 填滿黑霧
    ctx.fillStyle = FOG_CONFIG.FOG_COLOR;
    ctx.fillRect(0, 0, width, height);

    // 2. 設定混合模式（擦除）
    ctx.globalCompositeOperation = 'destination-out';

    // 3. 繪製所有解鎖軌跡
    state.paths.forEach(path => this.drawPath(path));

    // 4. 繪製所有解鎖點
    state.points.forEach(point => this.drawPoint(point));

    // 5. 重置混合模式
    ctx.globalCompositeOperation = 'source-over';
  }

  private drawPoint(point: UnlockPoint): void {
    const ctx = this.fogCtx;
    const { x, y } = this.coordSystem.geoToScreen(point.latitude, point.longitude);
    const radiusPx = this.coordSystem.metersToPixels(point.radius, point.latitude);

    // 徑向漸層
    const gradient = ctx.createRadialGradient(x, y, 0, x, y, radiusPx);
    gradient.addColorStop(0, 'rgba(255, 255, 255, 1)');
    gradient.addColorStop(1 - FOG_CONFIG.FOG_EDGE_BLUR, 'rgba(255, 255, 255, 1)');
    gradient.addColorStop(1, 'rgba(255, 255, 255, 0)');

    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.arc(x, y, radiusPx, 0, Math.PI * 2);
    ctx.fill();
  }

  private drawPath(path: UnlockPath): void {
    if (path.points.length < 2) return;

    const ctx = this.fogCtx;
    const widthPx = this.coordSystem.metersToPixels(path.width, path.points[0].latitude);

    ctx.lineWidth = widthPx;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.strokeStyle = 'rgba(255, 255, 255, 1)';

    ctx.beginPath();
    const start = this.coordSystem.geoToScreen(path.points[0].latitude, path.points[0].longitude);
    ctx.moveTo(start.x, start.y);

    for (let i = 1; i < path.points.length; i++) {
      const p = this.coordSystem.geoToScreen(path.points[i].latitude, path.points[i].longitude);
      ctx.lineTo(p.x, p.y);
    }

    ctx.stroke();
  }
}
```

### 4.7 解鎖動畫

```typescript
class FogAnimator {
  private renderer: FogRenderer;
  private activeAnimations: Map<string, Animation> = new Map();

  animateUnlock(point: UnlockPoint): void {
    const animation = {
      startTime: performance.now(),
      duration: FOG_CONFIG.UNLOCK_ANIMATION_DURATION,
      startRadius: 0,
      endRadius: point.radius,
      point,
    };

    this.activeAnimations.set(point.id, animation);
    this.tick();
  }

  animateStayExpand(point: UnlockPoint, fromRadius: number): void {
    const animation = {
      startTime: performance.now(),
      duration: FOG_CONFIG.STAY_EXPAND_DURATION,
      startRadius: fromRadius,
      endRadius: point.radius,
      point,
    };

    this.activeAnimations.set(point.id, animation);
    this.tick();
  }

  private tick = (): void => {
    const now = performance.now();
    let hasActive = false;

    this.activeAnimations.forEach((anim, id) => {
      const elapsed = now - anim.startTime;
      const progress = Math.min(elapsed / anim.duration, 1);
      const eased = 1 - Math.pow(1 - progress, 3);  // Ease-out

      anim.point.radius = anim.startRadius + (anim.endRadius - anim.startRadius) * eased;

      if (progress >= 1) {
        this.activeAnimations.delete(id);
      } else {
        hasActive = true;
      }
    });

    this.renderer.requestRender();

    if (hasActive) {
      requestAnimationFrame(this.tick);
    }
  };
}
```

### 4.8 狀態管理

```typescript
class FogManager {
  private state: FogState;
  private renderer: FogRenderer;
  private animator: FogAnimator;
  private storage: FogStorage;
  private currentPath: UnlockPath | null = null;

  readonly fogUpdated$ = new Subject<FogState>();
  readonly newAreaUnlocked$ = new Subject<number>();

  processValidLocation(location: ProcessedLocation): void {
    const { latitude, longitude } = location.point;
    const radius = FOG_CONFIG.UNLOCK_RADIUS_INSTANT;

    const point: UnlockPoint = {
      id: this.generateId(),
      latitude,
      longitude,
      radius,
      timestamp: Date.now(),
      type: UnlockType.WALK,
    };

    if (!this.shouldMergePoint(point)) {
      this.state.points.push(point);
      this.animator.animateUnlock(point);
    }

    this.updateCurrentPath(latitude, longitude);
    this.scheduleSync();
  }

  processStayEvent(stay: StayEvent): void {
    if (stay.duration < 45) return;

    const existingPoint = this.findNearbyPoint(stay.centerLat, stay.centerLng, 20);

    if (existingPoint) {
      const oldRadius = existingPoint.radius;
      existingPoint.radius = Math.max(existingPoint.radius, FOG_CONFIG.UNLOCK_RADIUS_STAY);
      this.animator.animateStayExpand(existingPoint, oldRadius);
    } else {
      const point: UnlockPoint = {
        id: this.generateId(),
        latitude: stay.centerLat,
        longitude: stay.centerLng,
        radius: FOG_CONFIG.UNLOCK_RADIUS_STAY,
        timestamp: Date.now(),
        type: UnlockType.STAY,
      };

      this.state.points.push(point);
      this.animator.animateUnlock(point);
    }

    this.scheduleSync();
  }

  private shouldMergePoint(newPoint: UnlockPoint): boolean {
    return this.findNearbyPoint(
      newPoint.latitude,
      newPoint.longitude,
      FOG_CONFIG.POINT_MERGE_DISTANCE
    ) !== null;
  }

  private findNearbyPoint(lat: number, lng: number, maxDist: number): UnlockPoint | null {
    for (const point of this.state.points) {
      const dist = haversineDistance(lat, lng, point.latitude, point.longitude);
      if (dist <= maxDist) return point;
    }
    return null;
  }
}
```

### 4.9 本地儲存 (SQLite)

```typescript
class FogStorage {
  private db: SQLiteDatabase;

  async init(): Promise<void> {
    await this.db.execute(`
      CREATE TABLE IF NOT EXISTS fog_points (
        id TEXT PRIMARY KEY,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radius REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        type TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    `);

    await this.db.execute(`
      CREATE TABLE IF NOT EXISTS fog_paths (
        id TEXT PRIMARY KEY,
        points TEXT NOT NULL,
        width REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        synced INTEGER DEFAULT 0
      )
    `);

    await this.db.execute(`
      CREATE INDEX IF NOT EXISTS idx_points_location
      ON fog_points(latitude, longitude)
    `);
  }

  async savePoint(point: UnlockPoint): Promise<void> {
    await this.db.execute(
      `INSERT OR REPLACE INTO fog_points
       (id, latitude, longitude, radius, timestamp, type, synced)
       VALUES (?, ?, ?, ?, ?, ?, 0)`,
      [point.id, point.latitude, point.longitude, point.radius, point.timestamp, point.type]
    );
  }

  async loadState(): Promise<FogState> {
    const points = await this.db.query<UnlockPoint>('SELECT * FROM fog_points');
    const pathRows = await this.db.query<any>('SELECT * FROM fog_paths');

    const paths = pathRows.map(row => ({
      ...row,
      points: JSON.parse(row.points),
    }));

    return { points, paths, totalUnlockedArea: 0, lastSyncTime: 0 };
  }
}
```

### 4.10 Firebase 同步

```typescript
class FogSyncService {
  private db = firebase.firestore();

  async performSync(): Promise<void> {
    const userId = getCurrentUserId();
    const unsyced = await this.storage.getUnsyncedData();

    if (unsyced.points.length === 0 && unsyced.paths.length === 0) return;

    const batch = this.db.batch();
    const userFogRef = this.db.collection('users').doc(userId).collection('fog');

    unsyced.points.forEach(point => {
      const docRef = userFogRef.doc(`point_${point.id}`);
      batch.set(docRef, {
        type: 'point',
        latitude: point.latitude,
        longitude: point.longitude,
        radius: point.radius,
        timestamp: firebase.firestore.Timestamp.fromMillis(point.timestamp),
        unlockType: point.type,
      });
    });

    unsyced.paths.forEach(path => {
      const docRef = userFogRef.doc(`path_${path.id}`);
      batch.set(docRef, {
        type: 'path',
        points: this.compressPoints(path.points),
        width: path.width,
        timestamp: firebase.firestore.Timestamp.fromMillis(path.timestamp),
      });
    });

    await batch.commit();
    await this.storage.markSynced(
      unsyced.points.map(p => p.id),
      unsyced.paths.map(p => p.id)
    );
  }

  // 壓縮軌跡點（delta encoding + base64）
  private compressPoints(points: Array<{ latitude: number; longitude: number }>): string {
    if (points.length === 0) return '';

    const deltas: number[] = [
      Math.round(points[0].latitude * 1e6),
      Math.round(points[0].longitude * 1e6),
    ];

    for (let i = 1; i < points.length; i++) {
      deltas.push(Math.round((points[i].latitude - points[i-1].latitude) * 1e6));
      deltas.push(Math.round((points[i].longitude - points[i-1].longitude) * 1e6));
    }

    return btoa(deltas.join(','));
  }
}
```

---

## 5. 模組 3：Cell 網格系統

### 5.1 架構

```
┌────────────────────────────────────────────────────────────┐
│                      CellService                            │
├────────────────────────────────────────────────────────────┤
│   ┌─────────────┐      ┌─────────────┐     ┌────────────┐ │
│   │ GeoEncoder  │─────▶│ CellManager │────▶│ Firestore  │ │
│   │ (座標→Cell) │      │ (本地快取)   │     │  (同步)    │ │
│   └─────────────┘      └─────────────┘     └────────────┘ │
└────────────────────────────────────────────────────────────┘
```

### 5.2 核心參數

```typescript
const CELL_CONFIG = {
  CELL_SIZE: 200,              // Cell 尺寸（公尺）
  EARTH_RADIUS: 6371000,       // 地球半徑
  COORD_PRECISION: 6,          // 經緯度精度
  CACHE_MAX_CELLS: 1000,       // 快取上限
  CACHE_TTL: 3600000,          // 快取 1 小時
  NEARBY_RADIUS: 3,            // 查詢周圍 3 格
};
```

### 5.3 資料結構

```typescript
interface Cell {
  cell_id: string;              // "lat_index:lng_index"
  lat_index: number;
  lng_index: number;
  center: {
    latitude: number;
    longitude: number;
  };
  bounds: {
    north: number;
    south: number;
    east: number;
    west: number;
  };
}

// Firestore 文件
interface CellActivity {
  cell_id: string;
  last_activity_time: Timestamp;
}

// 使用者 Cell 狀態
interface UserCellState {
  cell_id: string;
  unlocked: boolean;
  unlocked_at: number;
  last_visit: number;
  micro_event_cooldown?: number;
}
```

### 5.4 座標轉換

```typescript
class GeoEncoder {
  private readonly METERS_PER_LAT_DEGREE = 111320;

  private metersPerLngDegree(latitude: number): number {
    return this.METERS_PER_LAT_DEGREE * Math.cos(latitude * Math.PI / 180);
  }

  coordToCell(latitude: number, longitude: number): Cell {
    const latDegreesPerCell = CELL_CONFIG.CELL_SIZE / this.METERS_PER_LAT_DEGREE;
    const lngDegreesPerCell = CELL_CONFIG.CELL_SIZE / this.metersPerLngDegree(latitude);

    const lat_index = Math.floor(latitude / latDegreesPerCell);
    const lng_index = Math.floor(longitude / lngDegreesPerCell);

    const south = lat_index * latDegreesPerCell;
    const north = south + latDegreesPerCell;
    const west = lng_index * lngDegreesPerCell;
    const east = west + lngDegreesPerCell;

    return {
      cell_id: `${lat_index}:${lng_index}`,
      lat_index,
      lng_index,
      center: {
        latitude: (north + south) / 2,
        longitude: (east + west) / 2,
      },
      bounds: { north, south, east, west }
    };
  }

  parseCellId(cell_id: string): { lat_index: number; lng_index: number } {
    const [lat, lng] = cell_id.split(':').map(Number);
    return { lat_index: lat, lng_index: lng };
  }
}
```

### 5.5 鄰近查詢

```typescript
class CellQueryService {
  private geoEncoder = new GeoEncoder();

  getNearbyCells(
    latitude: number,
    longitude: number,
    radius: number = CELL_CONFIG.NEARBY_RADIUS
  ): Cell[] {
    const centerCell = this.geoEncoder.coordToCell(latitude, longitude);
    const cells: Cell[] = [];

    for (let dLat = -radius; dLat <= radius; dLat++) {
      for (let dLng = -radius; dLng <= radius; dLng++) {
        const cell = this.geoEncoder.indexToCell(
          centerCell.lat_index + dLat,
          centerCell.lng_index + dLng,
          latitude
        );
        cells.push(cell);
      }
    }

    return cells;
  }

  getCellsAlongPath(
    start: { latitude: number; longitude: number },
    end: { latitude: number; longitude: number }
  ): Cell[] {
    const cells: Map<string, Cell> = new Map();
    const startCell = this.geoEncoder.coordToCell(start.latitude, start.longitude);
    const endCell = this.geoEncoder.coordToCell(end.latitude, end.longitude);

    const dLat = Math.abs(endCell.lat_index - startCell.lat_index);
    const dLng = Math.abs(endCell.lng_index - startCell.lng_index);
    const steps = Math.max(dLat, dLng) + 1;

    for (let i = 0; i <= steps; i++) {
      const t = steps === 0 ? 0 : i / steps;
      const lat = start.latitude + (end.latitude - start.latitude) * t;
      const lng = start.longitude + (end.longitude - start.longitude) * t;
      const cell = this.geoEncoder.coordToCell(lat, lng);
      cells.set(cell.cell_id, cell);
    }

    return Array.from(cells.values());
  }
}
```

### 5.6 Firestore 操作

```typescript
class CellFirestore {
  private db = firebase.firestore();

  async recordActivity(cell_id: string): Promise<void> {
    const ref = this.db.collection('cells').doc(cell_id);
    await ref.set({
      last_activity_time: firebase.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
  }

  async getCellActivities(cell_ids: string[]): Promise<Map<string, CellActivity>> {
    const result = new Map<string, CellActivity>();
    const chunks = this.chunkArray(cell_ids, 10);

    for (const chunk of chunks) {
      const snapshot = await this.db
        .collection('cells')
        .where(firebase.firestore.FieldPath.documentId(), 'in', chunk)
        .get();

      snapshot.docs.forEach(doc => {
        result.set(doc.id, doc.data() as CellActivity);
      });
    }

    return result;
  }

  async unlockCell(user_id: string, cell_id: string): Promise<void> {
    const ref = this.db
      .collection('users')
      .doc(user_id)
      .collection('cells')
      .doc(cell_id);

    await ref.set({
      cell_id,
      unlocked: true,
      unlocked_at: firebase.firestore.FieldValue.serverTimestamp(),
      last_visit: firebase.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
  }

  private chunkArray<T>(array: T[], size: number): T[][] {
    const chunks: T[][] = [];
    for (let i = 0; i < array.length; i += size) {
      chunks.push(array.slice(i, i + size));
    }
    return chunks;
  }
}
```

### 5.7 主服務

```typescript
class CellService {
  private geoEncoder = new GeoEncoder();
  private queryService = new CellQueryService();
  private cache = new CellCache();
  private firestore = new CellFirestore();
  private currentCell: Cell | null = null;

  readonly cellChanged$ = new Subject<Cell>();
  readonly cellUnlocked$ = new Subject<Cell>();

  async processLocation(location: ProcessedLocation): Promise<void> {
    const { latitude, longitude } = location.point;
    const cell = this.geoEncoder.coordToCell(latitude, longitude);

    if (this.currentCell?.cell_id !== cell.cell_id) {
      this.currentCell = cell;
      this.cellChanged$.next(cell);

      const nearby = this.queryService.getNearbyCells(latitude, longitude);
      this.cache.preload(nearby, id => this.firestore.getUserCellState(userId, id));
    }

    await this.throttledRecordActivity(cell.cell_id);

    if (location.isValid) {
      await this.checkAndUnlock(cell);
    }
  }

  private lastActivityRecord: Map<string, number> = new Map();

  private async throttledRecordActivity(cell_id: string): Promise<void> {
    const now = Date.now();
    const last = this.lastActivityRecord.get(cell_id) || 0;

    if (now - last > 60000) {
      this.lastActivityRecord.set(cell_id, now);
      await this.firestore.recordActivity(cell_id);
    }
  }

  private async checkAndUnlock(cell: Cell): Promise<void> {
    const cached = this.cache.get(cell.cell_id);
    if (cached?.unlocked) return;

    await this.firestore.unlockCell(userId, cell.cell_id);

    const newState: UserCellState = {
      cell_id: cell.cell_id,
      unlocked: true,
      unlocked_at: Date.now(),
      last_visit: Date.now()
    };

    this.cache.set(cell.cell_id, newState);
    this.cellUnlocked$.next(cell);
  }
}
```

---

## 6. 模組 4：紅點系統

### 6.1 架構

```
┌────────────────────────────────────────────────────────────────────┐
│                        RedDotSystem                                 │
├────────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐    ┌──────────────┐    ┌───────────────────┐    │
│  │ ActivityFetch│───▶│ IntensityCalc│───▶│   RedDotRenderer  │    │
│  │ (Firestore)  │    │ (衰減計算)    │    │   (視覺呈現)       │    │
│  └──────────────┘    └──────────────┘    └───────────────────┘    │
└────────────────────────────────────────────────────────────────────┘
```

### 6.2 設計原則

| 原則 | 實作方式 |
|------|----------|
| **不顯示人數** | 只存 `last_activity_time`，不存 count |
| **不顯示誰** | 無 user_id 關聯 |
| **模糊位置** | Cell 中心 + 隨機偏移 |
| **自然衰減** | 指數衰減函數 |
| **只看已探索** | 過濾未解鎖 Cell |

### 6.3 核心參數

```typescript
const RED_DOT_CONFIG = {
  // 衰減參數
  DECAY_TAU_DAYS: 5,                    // τ = 5 天
  INTENSITY_THRESHOLD: 0.1,             // 低於此不顯示

  // 位置模糊
  OFFSET_MIN_METERS: 50,
  OFFSET_MAX_METERS: 100,

  // 視覺設定
  DOT_BASE_SIZE: 8,
  DOT_MAX_SIZE: 16,
  DOT_COLOR: 'rgba(255, 82, 82, 0.7)',
  DOT_GLOW_COLOR: 'rgba(255, 82, 82, 0.3)',

  // 動畫
  PULSE_DURATION: 3000,
  PULSE_SCALE_MIN: 0.8,
  PULSE_SCALE_MAX: 1.2,

  // 查詢設定
  FETCH_DEBOUNCE: 1000,
  CACHE_TTL: 60000,
  MAX_VISIBLE_DOTS: 50,
};
```

### 6.4 資料結構

```typescript
interface RedDot {
  id: string;
  cell_id: string;
  originalLat: number;
  originalLng: number;
  displayLat: number;
  displayLng: number;
  intensity: number;
  size: number;
  opacity: number;
  pulsePhase: number;
}
```

### 6.5 強度計算

```
intensity = exp(-Δt / τ)

其中：
  Δt = 現在時間 - last_activity_time（天）
  τ  = 5 天
```

| 經過天數 | intensity | 視覺效果 |
|----------|-----------|----------|
| 0 (剛剛) | 1.00 | 大、亮、明顯脈動 |
| 1 天 | 0.82 | 稍小、稍暗 |
| 3 天 | 0.55 | 中等 |
| 5 天 | 0.37 | 較小、較暗 |
| 10 天 | 0.14 | 很小、很暗 |
| 15 天 | 0.05 | 不顯示 |

```typescript
class IntensityCalculator {
  private readonly TAU_MS = RED_DOT_CONFIG.DECAY_TAU_DAYS * 24 * 60 * 60 * 1000;

  calculate(lastActivityTime: number): number {
    const now = Date.now();
    const deltaMs = now - lastActivityTime;

    if (deltaMs < 0) return 1;

    return Math.exp(-deltaMs / this.TAU_MS);
  }

  processActivities(activities: CellActivity[]): Map<string, number> {
    const result = new Map<string, number>();

    activities.forEach(activity => {
      const intensity = this.calculate(activity.last_activity_time);

      if (intensity >= RED_DOT_CONFIG.INTENSITY_THRESHOLD) {
        result.set(activity.cell_id, intensity);
      }
    });

    return result;
  }
}
```

### 6.6 位置模糊

```typescript
class PositionObfuscator {
  private offsetCache: Map<string, { dLat: number; dLng: number }> = new Map();

  getOffset(cell_id: string): { dLat: number; dLng: number } {
    const cached = this.offsetCache.get(cell_id);
    if (cached) return cached;

    // 使用 cell_id 作為種子，確保同一 Cell 偏移一致
    const seed = this.hashString(cell_id);
    const random1 = this.seededRandom(seed);
    const random2 = this.seededRandom(seed + 1);

    const distance = RED_DOT_CONFIG.OFFSET_MIN_METERS +
      random1 * (RED_DOT_CONFIG.OFFSET_MAX_METERS - RED_DOT_CONFIG.OFFSET_MIN_METERS);

    const angle = random2 * Math.PI * 2;

    const dLat = (distance * Math.cos(angle)) / 111320;
    const dLng = (distance * Math.sin(angle)) / 111320;

    const offset = { dLat, dLng };
    this.offsetCache.set(cell_id, offset);

    return offset;
  }

  applyOffset(cell: Cell): { latitude: number; longitude: number } {
    const offset = this.getOffset(cell.cell_id);

    return {
      latitude: cell.center.latitude + offset.dLat,
      longitude: cell.center.longitude + offset.dLng,
    };
  }

  private hashString(str: string): number {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return Math.abs(hash);
  }

  private seededRandom(seed: number): number {
    const x = Math.sin(seed) * 10000;
    return x - Math.floor(x);
  }
}
```

### 6.7 紅點渲染器

```typescript
class RedDotRenderer {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private currentDots: RedDot[] = [];

  render(timestamp: number): void {
    const ctx = this.ctx;
    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

    this.currentDots.forEach(dot => {
      this.renderDot(dot, timestamp);
    });
  }

  private renderDot(dot: RedDot, timestamp: number): void {
    const ctx = this.ctx;
    const { x, y } = this.coordSystem.geoToScreen(dot.displayLat, dot.displayLng);

    // 檢查是否在畫面內
    if (x < -50 || x > this.canvas.width + 50 ||
        y < -50 || y > this.canvas.height + 50) {
      return;
    }

    // 脈動效果
    const pulseProgress = ((timestamp / RED_DOT_CONFIG.PULSE_DURATION) + dot.pulsePhase) % 1;
    const pulseScale = this.calculatePulseScale(pulseProgress, dot.intensity);
    const currentSize = dot.size * pulseScale;

    // 繪製外發光
    this.drawGlow(x, y, currentSize, dot.opacity);

    // 繪製核心圓點
    this.drawCore(x, y, currentSize, dot.opacity);
  }

  private drawGlow(x: number, y: number, size: number, opacity: number): void {
    const ctx = this.ctx;
    const glowRadius = size * 2;

    const gradient = ctx.createRadialGradient(x, y, 0, x, y, glowRadius);
    gradient.addColorStop(0, `rgba(255, 82, 82, ${opacity * 0.4})`);
    gradient.addColorStop(0.5, `rgba(255, 82, 82, ${opacity * 0.15})`);
    gradient.addColorStop(1, 'rgba(255, 82, 82, 0)');

    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.arc(x, y, glowRadius, 0, Math.PI * 2);
    ctx.fill();
  }

  private drawCore(x: number, y: number, size: number, opacity: number): void {
    const ctx = this.ctx;

    const gradient = ctx.createRadialGradient(x, y, 0, x, y, size);
    gradient.addColorStop(0, `rgba(255, 100, 100, ${opacity})`);
    gradient.addColorStop(0.6, `rgba(255, 82, 82, ${opacity * 0.8})`);
    gradient.addColorStop(1, `rgba(255, 60, 60, 0)`);

    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.arc(x, y, size, 0, Math.PI * 2);
    ctx.fill();
  }
}
```

### 6.8 主服務

```typescript
class RedDotService {
  private intensityCalc = new IntensityCalculator();
  private obfuscator = new PositionObfuscator();
  private cache: RedDotCacheEntry | null = null;

  readonly redDotsUpdated$ = new Subject<RedDot[]>();

  async getRedDotsInViewport(
    viewport: ViewportBounds,
    userUnlockedCells: Set<string>
  ): Promise<RedDot[]> {
    if (this.isCacheValid(viewport)) {
      return this.cache!.dots;
    }

    const visibleCellIds = this.getCellsInViewport(viewport);
    const unlockedVisibleCells = visibleCellIds.filter(id => userUnlockedCells.has(id));

    if (unlockedVisibleCells.length === 0) return [];

    const activities = await this.cellFirestore.getCellActivities(unlockedVisibleCells);
    const intensities = this.intensityCalc.processActivities(Array.from(activities.values()));
    const dots = this.convertToRedDots(intensities, viewport);

    this.cache = { dots, fetchTime: Date.now(), viewport };

    return dots;
  }

  private convertToRedDots(intensities: Map<string, number>, viewport: ViewportBounds): RedDot[] {
    const dots: RedDot[] = [];

    intensities.forEach((intensity, cell_id) => {
      const cell = this.geoEncoder.cellIdToCell(cell_id);
      const displayPos = this.obfuscator.applyOffset(cell);

      const size = this.calculateSize(intensity);
      const opacity = this.calculateOpacity(intensity);

      dots.push({
        id: cell_id,
        cell_id,
        originalLat: cell.center.latitude,
        originalLng: cell.center.longitude,
        displayLat: displayPos.latitude,
        displayLng: displayPos.longitude,
        intensity,
        size,
        opacity,
        pulsePhase: Math.random(),
      });
    });

    dots.sort((a, b) => b.intensity - a.intensity);
    return dots.slice(0, RED_DOT_CONFIG.MAX_VISIBLE_DOTS);
  }

  private calculateSize(intensity: number): number {
    const { DOT_BASE_SIZE, DOT_MAX_SIZE } = RED_DOT_CONFIG;
    const t = Math.pow(intensity, 0.7);
    return DOT_BASE_SIZE + (DOT_MAX_SIZE - DOT_BASE_SIZE) * t;
  }

  private calculateOpacity(intensity: number): number {
    return 0.3 + intensity * 0.6;
  }
}
```

---

## 7. 模組 5：微事件系統

### 7.1 架構

```
┌──────────────────────────────────────────────────────────────────────┐
│                       MicroEventSystem                                │
├──────────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐    ┌──────────────┐    ┌─────────────────────┐    │
│  │TriggerDetector│───▶│ CooldownMgr │───▶│  EventDispatcher    │    │
│  │ (條件判定)    │    │ (冷卻檢查)   │    │  (內容選擇+顯示)    │    │
│  └──────────────┘    └──────────────┘    └─────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
```

### 7.2 設計原則

| 原則 | 實作方式 |
|------|----------|
| **不可預測** | 25% 機率觸發 |
| **不可刷** | Cell 冷卻 24hr + 每日上限 3 次 |
| **不可重看** | 顯示後立即消失，無歷史記錄 |
| **極簡呈現** | 單行文字，3-5 秒淡出 |
| **神秘感** | 內容模糊、不解釋 |

### 7.3 核心參數

```typescript
const MICRO_EVENT_CONFIG = {
  // 觸發條件
  TRIGGER_STAY_DURATION: 45,        // 停留秒數
  TRIGGER_PROBABILITY: 0.25,        // 25% 機率
  REQUIRE_RED_DOT: true,            // 必須有紅點

  // 冷卻設定
  CELL_COOLDOWN_HOURS: 24,          // 同 Cell 冷卻 24 小時
  DAILY_MAX_EVENTS: 3,              // 每日最多觸發次數

  // 顯示設定
  DISPLAY_DURATION: 4000,           // 顯示時長（ms）
  FADE_IN_DURATION: 800,            // 淡入時長（ms）
  FADE_OUT_DURATION: 1200,          // 淡出時長（ms）

  // 文字樣式
  FONT_SIZE: 16,
  FONT_COLOR: 'rgba(255, 255, 255, 0.9)',
  FONT_FAMILY: 'system-ui, sans-serif',
  TEXT_SHADOW: '0 2px 8px rgba(0, 0, 0, 0.5)',

  // 位置
  POSITION_Y_RATIO: 0.4,            // 螢幕高度 40% 處
};
```

### 7.4 資料結構

```typescript
interface MicroEvent {
  id: string;
  text: string;
  category: EventCategory;
  weight: number;
}

enum EventCategory {
  PRESENCE = 'presence',
  TIME = 'time',
  SPACE = 'space',
  CONNECTION = 'connection',
}

interface TriggerContext {
  cell_id: string;
  stayDuration: number;
  hasRedDot: boolean;
  redDotIntensity?: number;
  timestamp: number;
}

interface CooldownState {
  cellCooldowns: Map<string, number>;
  dailyCount: number;
  dailyResetTime: number;
}

interface DisplayEvent {
  id: string;
  text: string;
  startTime: number;
  phase: DisplayPhase;
}

enum DisplayPhase {
  FADE_IN = 'fade_in',
  VISIBLE = 'visible',
  FADE_OUT = 'fade_out',
  DONE = 'done',
}
```

### 7.5 文案庫

```typescript
const MICRO_EVENT_TEXTS: MicroEvent[] = [
  // 存在感 (PRESENCE)
  { id: 'p1', text: '你不是第一個走到這裡的人。', category: EventCategory.PRESENCE, weight: 10 },
  { id: 'p2', text: '這附近，有人停下來過。', category: EventCategory.PRESENCE, weight: 10 },
  { id: 'p3', text: '有人曾在這裡駐足。', category: EventCategory.PRESENCE, weight: 8 },
  { id: 'p4', text: '這裡留有痕跡。', category: EventCategory.PRESENCE, weight: 6 },
  { id: 'p5', text: '不只你經過這裡。', category: EventCategory.PRESENCE, weight: 8 },

  // 時間感 (TIME)
  { id: 't1', text: '時間在這裡流過。', category: EventCategory.TIME, weight: 6 },
  { id: 't2', text: '某個時刻，有人也在這。', category: EventCategory.TIME, weight: 8 },
  { id: 't3', text: '這一刻與另一刻重疊了。', category: EventCategory.TIME, weight: 5 },

  // 空間感 (SPACE)
  { id: 's1', text: '這片地方被記住了。', category: EventCategory.SPACE, weight: 7 },
  { id: 's2', text: '有人的路徑經過這裡。', category: EventCategory.SPACE, weight: 9 },
  { id: 's3', text: '世界在這裡被照亮過。', category: EventCategory.SPACE, weight: 6 },

  // 連結感 (CONNECTION)
  { id: 'c1', text: '你們的軌跡交會了。', category: EventCategory.CONNECTION, weight: 5 },
  { id: 'c2', text: '某人走過同樣的路。', category: EventCategory.CONNECTION, weight: 8 },
  { id: 'c3', text: '這裡連結著另一個人。', category: EventCategory.CONNECTION, weight: 4 },
];
```

### 7.6 冷卻管理

```typescript
class CooldownManager {
  private state: CooldownState;
  private storage: LocalStorage;
  private readonly STORAGE_KEY = 'micro_event_cooldown';

  canTrigger(cell_id: string): { allowed: boolean; reason?: string } {
    // 檢查每日上限
    if (this.state.dailyCount >= MICRO_EVENT_CONFIG.DAILY_MAX_EVENTS) {
      return { allowed: false, reason: 'daily_limit_reached' };
    }

    // 檢查 Cell 冷卻
    const cooldownEnd = this.state.cellCooldowns.get(cell_id);
    if (cooldownEnd && Date.now() < cooldownEnd) {
      return { allowed: false, reason: 'cell_cooldown' };
    }

    return { allowed: true };
  }

  recordTrigger(cell_id: string): void {
    const cooldownEnd = Date.now() + MICRO_EVENT_CONFIG.CELL_COOLDOWN_HOURS * 60 * 60 * 1000;
    this.state.cellCooldowns.set(cell_id, cooldownEnd);
    this.state.dailyCount++;
    this.cleanExpiredCooldowns();
    this.saveState();
  }

  getRemainingToday(): number {
    this.checkDailyReset();
    return MICRO_EVENT_CONFIG.DAILY_MAX_EVENTS - this.state.dailyCount;
  }

  private checkDailyReset(): void {
    const todayStart = this.getTodayStartTime();

    if (this.state.dailyResetTime < todayStart) {
      this.state.dailyCount = 0;
      this.state.dailyResetTime = todayStart;
      this.saveState();
    }
  }

  // 凌晨 4 點作為一天的開始
  private getTodayStartTime(): number {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 4, 0, 0, 0);
    if (now < today) today.setDate(today.getDate() - 1);
    return today.getTime();
  }
}
```

### 7.7 觸發偵測

```typescript
class TriggerDetector {
  private currentCell: string | null = null;
  private cellEnterTime: number = 0;
  private checkInterval: number | null = null;

  readonly triggerDetected$ = new Subject<TriggerContext>();

  private onCellChanged(cell: Cell): void {
    this.stopChecking();
    this.currentCell = cell.cell_id;
    this.cellEnterTime = Date.now();
    this.startChecking(cell);
  }

  private startChecking(cell: Cell): void {
    const redDot = this.redDotService.getRedDotForCell(cell.cell_id);

    if (!redDot && MICRO_EVENT_CONFIG.REQUIRE_RED_DOT) return;

    this.checkInterval = setInterval(() => {
      this.checkTriggerCondition(cell, redDot);
    }, 1000);
  }

  private checkTriggerCondition(cell: Cell, redDot: RedDot | null): void {
    const stayDuration = (Date.now() - this.cellEnterTime) / 1000;

    if (stayDuration < MICRO_EVENT_CONFIG.TRIGGER_STAY_DURATION) return;

    this.stopChecking();

    const context: TriggerContext = {
      cell_id: cell.cell_id,
      stayDuration,
      hasRedDot: redDot !== null,
      redDotIntensity: redDot?.intensity,
      timestamp: Date.now(),
    };

    this.triggerDetected$.next(context);
  }
}
```

### 7.8 文案選擇

```typescript
class TextSelector {
  private events: MicroEvent[] = MICRO_EVENT_TEXTS;
  private recentlyUsed: string[] = [];
  private readonly RECENT_LIMIT = 5;

  select(context: TriggerContext): MicroEvent {
    const available = this.events.filter(e => !this.recentlyUsed.includes(e.id));
    const pool = available.length > 0 ? available : this.events;
    const weighted = this.applyContextWeight(pool, context);
    const selected = this.weightedRandom(weighted);
    this.recordUsage(selected.id);
    return selected;
  }

  private applyContextWeight(events: MicroEvent[], context: TriggerContext): MicroEvent[] {
    return events.map(event => {
      let weight = event.weight;

      // 紅點強度高 → 偏好「連結感」類
      if (context.redDotIntensity && context.redDotIntensity > 0.7) {
        if (event.category === EventCategory.CONNECTION) weight *= 1.5;
      }

      // 停留時間長 → 偏好「時間感」類
      if (context.stayDuration > 90) {
        if (event.category === EventCategory.TIME) weight *= 1.3;
      }

      return { ...event, weight };
    });
  }

  private weightedRandom(events: MicroEvent[]): MicroEvent {
    const totalWeight = events.reduce((sum, e) => sum + e.weight, 0);
    let random = Math.random() * totalWeight;

    for (const event of events) {
      random -= event.weight;
      if (random <= 0) return event;
    }

    return events[events.length - 1];
  }
}
```

### 7.9 事件分發

```typescript
class EventDispatcher {
  private cooldownManager: CooldownManager;
  private textSelector: TextSelector;

  readonly eventTriggered$ = new Subject<DisplayEvent>();

  handleTrigger(context: TriggerContext): void {
    // 1. 檢查冷卻
    const canTrigger = this.cooldownManager.canTrigger(context.cell_id);
    if (!canTrigger.allowed) return;

    // 2. 機率判定 (25%)
    if (Math.random() >= MICRO_EVENT_CONFIG.TRIGGER_PROBABILITY) return;

    // 3. 選擇文案
    const event = this.textSelector.select(context);

    // 4. 記錄觸發
    this.cooldownManager.recordTrigger(context.cell_id);

    // 5. 發出顯示事件
    const displayEvent: DisplayEvent = {
      id: `${context.cell_id}_${Date.now()}`,
      text: event.text,
      startTime: Date.now(),
      phase: DisplayPhase.FADE_IN,
    };

    this.eventTriggered$.next(displayEvent);
  }
}
```

### 7.10 UI 渲染（Flutter）

```dart
class MicroEventOverlay extends StatefulWidget {
  final Stream<DisplayEvent> eventStream;

  @override
  _MicroEventOverlayState createState() => _MicroEventOverlayState();
}

class _MicroEventOverlayState extends State<MicroEventOverlay>
    with SingleTickerProviderStateMixin {

  String? _currentText;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(
        milliseconds: MICRO_EVENT_CONFIG.FADE_IN_DURATION +
                     MICRO_EVENT_CONFIG.DISPLAY_DURATION +
                     MICRO_EVENT_CONFIG.FADE_OUT_DURATION,
      ),
      vsync: this,
    );

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: MICRO_EVENT_CONFIG.FADE_IN_DURATION.toDouble(),
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: MICRO_EVENT_CONFIG.DISPLAY_DURATION.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: MICRO_EVENT_CONFIG.FADE_OUT_DURATION.toDouble(),
      ),
    ]).animate(_controller);

    widget.eventStream.listen(_onEvent);
  }

  void _onEvent(DisplayEvent event) {
    setState(() => _currentText = event.text);
    _controller.forward(from: 0).then((_) {
      setState(() => _currentText = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentText == null) return SizedBox.shrink();

    return Positioned(
      left: 0,
      right: 0,
      top: MediaQuery.of(context).size.height * MICRO_EVENT_CONFIG.POSITION_Y_RATIO,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Text(
          _currentText!,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: MICRO_EVENT_CONFIG.FONT_SIZE,
            color: Colors.white.withOpacity(0.9),
            shadows: [
              Shadow(blurRadius: 8, color: Colors.black.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
```

### 7.11 完整資料流

```
GPS 位置更新
    │
    ▼
CellService (Cell 變化)
    │ cellChanged$
    ▼
TriggerDetector (停留偵測)  ◄──── RedDotService (紅點檢查)
    │ triggerDetected$ (停留 ≥ 45s + 有紅點)
    ▼
CooldownManager (冷卻檢查)
    │ canTrigger?
    ▼
EventDispatcher (機率 25% + 選擇文案)
    │ eventTriggered$
    ▼
MicroEventRenderer (顯示動畫)
```

---

## 8. 模組 6：推播系統

### 8.1 架構

```
┌────────────────────────────────────────────────────────────────────┐
│                        PushSystem                                   │
├────────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐    ┌──────────────┐    ┌───────────────────┐    │
│  │ PushTrigger  │───▶│ PushManager  │───▶│  Local Push API   │    │
│  │ (條件偵測)    │    │ (頻率控制)    │    │  (發送推播)        │    │
│  └──────────────┘    └──────────────┘    └───────────────────┘    │
└────────────────────────────────────────────────────────────────────┘
```

### 8.2 設計原則

| 原則 | 實作方式 |
|------|----------|
| **極簡** | 每天最多 1 則 |
| **有意義** | 只在實際解鎖新區域時發送 |
| **不打擾** | 不催促、不提醒回來玩 |
| **詩意** | 文案簡短、留白 |

### 8.3 核心參數

```typescript
const PUSH_CONFIG = {
  MAX_DAILY_PUSH: 1,
  MIN_INTERVAL_HOURS: 20,
  TRIGGER_TYPE: 'first_unlock_today',
  CHANNEL_ID: 'fog_unlock',
  CHANNEL_NAME: '地圖解鎖',
  PRIORITY: 'default',
  QUIET_HOURS_START: 22,
  QUIET_HOURS_END: 8,
};
```

### 8.4 資料結構

```typescript
interface PushState {
  lastPushTime: number;
  lastPushDate: string;
  todayPushCount: number;
  fcmToken: string | null;
  permissionGranted: boolean;
}

interface PushPayload {
  title: string;
  body: string;
  data?: { type: string; cell_id?: string };
}

interface PushMessage {
  id: string;
  body: string;
  weight: number;
}
```

### 8.5 文案庫

```typescript
const PUSH_MESSAGES: PushMessage[] = [
  { id: 'msg_1', body: '世界剛剛多亮了一點。', weight: 10 },
  { id: 'msg_2', body: '你今天走出了一段路。', weight: 10 },
  { id: 'msg_3', body: '新的地方被記住了。', weight: 8 },
  { id: 'msg_4', body: '又有一塊霧散開了。', weight: 8 },
  { id: 'msg_5', body: '地圖上多了一道光。', weight: 7 },
  { id: 'msg_6', body: '這裡，被你照亮了。', weight: 6 },
  { id: 'msg_7', body: '足跡延伸了一些。', weight: 7 },
  { id: 'msg_8', body: '世界又大了一點點。', weight: 8 },
];
```

### 8.6 推播觸發

```typescript
class PushTrigger {
  private todayHasUnlocked: boolean = false;
  private lastCheckDate: string = '';

  readonly shouldPush$ = new Subject<{ cell_id: string }>();

  private onCellUnlocked(cell: Cell): void {
    const today = this.getTodayString();

    if (today !== this.lastCheckDate) {
      this.todayHasUnlocked = false;
      this.lastCheckDate = today;
    }

    if (!this.todayHasUnlocked) {
      this.todayHasUnlocked = true;
      this.shouldPush$.next({ cell_id: cell.cell_id });
    }
  }
}
```

### 8.7 推播管理

```typescript
class PushManager {
  private state: PushState;

  async handleTrigger(context: { cell_id: string }): Promise<boolean> {
    if (!this.state.permissionGranted) return false;
    if (!this.canPushNow()) return false;
    if (this.isQuietHours()) return false;

    const message = this.messageSelector.select();

    await this.sendLocalNotification({
      title: '',
      body: message.body,
      data: { type: 'fog_unlock', cell_id: context.cell_id },
    });

    this.recordPush();
    return true;
  }

  private canPushNow(): boolean {
    const today = this.getTodayString();

    if (this.state.lastPushDate === today) {
      if (this.state.todayPushCount >= PUSH_CONFIG.MAX_DAILY_PUSH) {
        return false;
      }
    }

    const minIntervalMs = PUSH_CONFIG.MIN_INTERVAL_HOURS * 60 * 60 * 1000;
    if (Date.now() - this.state.lastPushTime < minIntervalMs) {
      return false;
    }

    return true;
  }

  private isQuietHours(): boolean {
    const hour = new Date().getHours();
    const { QUIET_HOURS_START, QUIET_HOURS_END } = PUSH_CONFIG;

    if (QUIET_HOURS_START > QUIET_HOURS_END) {
      return hour >= QUIET_HOURS_START || hour < QUIET_HOURS_END;
    }

    return hour >= QUIET_HOURS_START && hour < QUIET_HOURS_END;
  }

  private recordPush(): void {
    const today = this.getTodayString();

    if (this.state.lastPushDate !== today) {
      this.state.todayPushCount = 0;
      this.state.lastPushDate = today;
    }

    this.state.lastPushTime = Date.now();
    this.state.todayPushCount++;
    this.saveState();
  }
}
```

### 8.8 Flutter 實作

```dart
class PushService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
    await _createNotificationChannel();
  }

  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'fog_unlock',
      '地圖解鎖',
      description: '當你解鎖新區域時收到通知',
      importance: Importance.defaultImportance,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> showNotification(String body) async {
    const androidDetails = AndroidNotificationDetails(
      'fog_unlock',
      '地圖解鎖',
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

    await _notifications.show(0, null, body, details);
  }
}
```

### 8.9 平台設定

#### Android (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

#### iOS (Info.plist)

```xml
<key>UIBackgroundModes</key>
<array>
  <string>remote-notification</string>
</array>
```

---

## 9. Firebase 設定

### 9.1 Firestore 結構

```
firestore/
├── cells/                          # 全域 Cell 活動（紅點用）
│   └── {cell_id}/
│       └── last_activity_time: Timestamp
│
└── users/
    └── {user_id}/
        ├── fcmToken: string
        ├── fcmTokenUpdatedAt: Timestamp
        │
        ├── cells/                  # 使用者的 Cell 狀態
        │   └── {cell_id}/
        │       ├── unlocked: boolean
        │       ├── unlocked_at: Timestamp
        │       └── last_visit: Timestamp
        │
        └── fog/                    # 使用者的 Fog 資料
            ├── point_{id}/
            │   ├── type: "point"
            │   ├── latitude: number
            │   ├── longitude: number
            │   ├── radius: number
            │   ├── timestamp: Timestamp
            │   └── unlockType: "walk" | "stay"
            │
            └── path_{id}/
                ├── type: "path"
                ├── points: string (compressed)
                ├── width: number
                └── timestamp: Timestamp
```

### 9.2 安全規則

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // 全域 Cell 活動
    match /cells/{cellId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
        && request.resource.data.keys().hasOnly(['last_activity_time'])
        && request.resource.data.last_activity_time == request.time;
    }

    // 使用者個人資料
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      match /cells/{cellId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }

      match /fog/{fogId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

### 9.3 索引設定

```json
{
  "indexes": [
    {
      "collectionGroup": "cells",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "last_activity_time", "order": "DESCENDING" }
      ]
    }
  ]
}
```

---

## 10. 開發建議

### 10.1 模組開發順序

```
1. GPS 追蹤 (模組 1) ──────┐
                          │
2. Cell 網格 (模組 3) ─────┼──▶ 3. Fog 系統 (模組 2)
                          │
4. 紅點系統 (模組 4) ──────┘

5. 微事件 (模組 5)

6. 推播 (模組 6)
```

### 10.2 Flutter 依賴

```yaml
dependencies:
  flutter:
    sdk: flutter

  # 位置
  geolocator: ^10.0.0
  flutter_background_service: ^5.0.0

  # Firebase
  firebase_core: ^2.0.0
  firebase_auth: ^4.0.0
  cloud_firestore: ^4.0.0
  firebase_messaging: ^14.0.0

  # 本地儲存
  sqflite: ^2.3.0
  shared_preferences: ^2.2.0

  # 推播
  flutter_local_notifications: ^16.0.0

  # 工具
  rxdart: ^0.27.0
  uuid: ^4.0.0
```

### 10.3 專案結構

```
lib/
├── main.dart
├── app.dart
│
├── core/
│   ├── config/
│   │   └── constants.dart
│   ├── utils/
│   │   ├── geo_utils.dart
│   │   └── haversine.dart
│   └── services/
│       └── storage_service.dart
│
├── features/
│   ├── location/
│   │   ├── location_service.dart
│   │   ├── speed_calculator.dart
│   │   ├── drift_filter.dart
│   │   └── stay_detector.dart
│   │
│   ├── cell/
│   │   ├── cell_service.dart
│   │   ├── geo_encoder.dart
│   │   ├── cell_cache.dart
│   │   └── cell_firestore.dart
│   │
│   ├── fog/
│   │   ├── fog_manager.dart
│   │   ├── fog_renderer.dart
│   │   ├── fog_animator.dart
│   │   ├── fog_storage.dart
│   │   └── fog_sync_service.dart
│   │
│   ├── red_dot/
│   │   ├── red_dot_service.dart
│   │   ├── intensity_calculator.dart
│   │   ├── position_obfuscator.dart
│   │   └── red_dot_renderer.dart
│   │
│   ├── micro_event/
│   │   ├── micro_event_service.dart
│   │   ├── trigger_detector.dart
│   │   ├── cooldown_manager.dart
│   │   ├── event_dispatcher.dart
│   │   ├── text_selector.dart
│   │   └── micro_event_texts.dart
│   │
│   └── push/
│       ├── push_service.dart
│       ├── push_manager.dart
│       ├── push_trigger.dart
│       └── push_messages.dart
│
├── ui/
│   ├── screens/
│   │   └── map_screen.dart
│   ├── widgets/
│   │   ├── fog_layer.dart
│   │   ├── red_dot_layer.dart
│   │   └── micro_event_overlay.dart
│   └── painters/
│       ├── fog_painter.dart
│       └── red_dot_painter.dart
│
└── data/
    ├── models/
    │   ├── location_point.dart
    │   ├── cell.dart
    │   ├── unlock_point.dart
    │   ├── red_dot.dart
    │   └── micro_event.dart
    └── repositories/
        ├── cell_repository.dart
        └── fog_repository.dart
```

### 10.4 開發估算

| 模組 | 預估工時 |
|------|----------|
| GPS 追蹤 | 3-4 天 |
| Cell 網格 | 2-3 天 |
| Fog 系統 | 5-7 天 |
| 紅點系統 | 3-4 天 |
| 微事件 | 2-3 天 |
| 推播 | 1-2 天 |
| UI 整合 | 3-4 天 |
| 測試調校 | 3-5 天 |
| **總計** | **22-32 天** |

---

## 結語

> 這不是一個要「被玩懂」的產品，
> 而是一個要「被走出來」的世界。
