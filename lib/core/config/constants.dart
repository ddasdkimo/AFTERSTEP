/// 《現實世界 Fog》核心常數配置
///
/// 此檔案包含所有模組的配置參數，依據 TECHNICAL_SPEC.md 定義。
library;

// =============================================================================
// GPS 追蹤與速度判定配置
// =============================================================================

class GpsConfig {
  GpsConfig._();

  /// 前景取樣間隔 (毫秒)
  static const int intervalForeground = 3000;

  /// 背景取樣間隔 (毫秒)
  static const int intervalBackground = 5000;

  /// 精度門檻 (公尺) - 精度大於此值視為無效
  static const double accuracyThreshold = 20.0;

  /// 最低有效速度 (m/s) - 低於此為靜止
  static const double speedMin = 0.6;

  /// 最佳步行速度 (m/s)
  static const double speedOptimal = 1.2;

  /// 步行速度上限 (m/s) - 高於此開始遞減
  static const double speedMax = 1.8;

  /// 速度截止值 (m/s) - 高於此完全無效
  static const double speedCutoff = 2.5;

  /// 漂移判定門檻 (公尺) - 靜止時移動超過此距離視為漂移
  static const double driftThreshold = 3.0;

  /// 漂移判定時間窗口 (毫秒)
  static const int driftTimeWindow = 10000;

  /// 停留判定半徑 (公尺)
  static const double stayRadius = 15.0;

  /// 最短停留時間 (秒)
  static const int stayMinDuration = 45;

  /// 即時解鎖半徑 (公尺)
  static const double unlockRadiusInstant = 15.0;

  /// 停留擴散半徑 (公尺)
  static const double unlockRadiusStay = 40.0;

  /// 速度計算緩衝區大小
  static const int speedBufferSize = 5;
}

// =============================================================================
// Fog 解鎖與渲染配置
// =============================================================================

class FogConfig {
  FogConfig._();

  /// 即時解鎖半徑 (公尺)
  static const double unlockRadiusInstant = 15.0;

  /// 停留擴散半徑 (公尺)
  static const double unlockRadiusStay = 40.0;

  /// 霧的顏色 (ARGB)
  static const int fogColor = 0xFF0F0F14;

  /// 邊緣模糊比例 (0-1)
  static const double fogEdgeBlur = 0.3;

  /// 合併距離 - 小於此距離的點會被合併 (公尺)
  static const double pointMergeDistance = 5.0;

  /// 記憶體最大點數
  static const int maxPointsInMemory = 10000;

  /// 離屏 Canvas Tile 尺寸 (像素)
  static const int tileSize = 512;

  /// 解鎖動畫時長 (毫秒)
  static const int unlockAnimationDuration = 300;

  /// 停留擴散動畫時長 (毫秒)
  static const int stayExpandDuration = 2000;

  /// 同步防抖時間 (毫秒)
  static const int syncDebounce = 5000;

  /// 批次同步點數
  static const int syncBatchSize = 100;
}

// =============================================================================
// Cell 網格系統配置
// =============================================================================

class CellConfig {
  CellConfig._();

  /// Cell 尺寸 (公尺)
  static const double cellSize = 200.0;

  /// 地球半徑 (公尺)
  static const double earthRadius = 6371000.0;

  /// 經緯度精度
  static const int coordPrecision = 6;

  /// 快取最大 Cell 數量
  static const int cacheMaxCells = 1000;

  /// 快取有效時間 (毫秒)
  static const int cacheTtl = 3600000;

  /// 查詢周圍格數
  static const int nearbyRadius = 3;

  /// 每緯度公尺數
  static const double metersPerLatDegree = 111320.0;
}

// =============================================================================
// 紅點系統配置
// =============================================================================

class RedDotConfig {
  RedDotConfig._();

  /// 衰減時間常數 τ (天)
  static const double decayTauDays = 5.0;

  /// 強度門檻 - 低於此不顯示
  static const double intensityThreshold = 0.1;

  /// 位置偏移最小距離 (公尺)
  static const double offsetMinMeters = 50.0;

  /// 位置偏移最大距離 (公尺)
  static const double offsetMaxMeters = 100.0;

  /// 紅點基本尺寸 (像素)
  static const double dotBaseSize = 8.0;

  /// 紅點最大尺寸 (像素)
  static const double dotMaxSize = 16.0;

  /// 紅點顏色 (ARGB)
  static const int dotColor = 0xB3FF5252;

  /// 紅點發光顏色 (ARGB)
  static const int dotGlowColor = 0x4DFF5252;

  /// 脈動動畫時長 (毫秒)
  static const int pulseDuration = 3000;

  /// 脈動最小縮放
  static const double pulseScaleMin = 0.8;

  /// 脈動最大縮放
  static const double pulseScaleMax = 1.2;

  /// 查詢防抖時間 (毫秒)
  static const int fetchDebounce = 1000;

  /// 快取有效時間 (毫秒)
  static const int cacheTtl = 60000;

  /// 最大可見紅點數量
  static const int maxVisibleDots = 50;
}

// =============================================================================
// 微事件系統配置
// =============================================================================

class MicroEventConfig {
  MicroEventConfig._();

  /// 觸發停留時間 (秒)
  static const int triggerStayDuration = 45;

  /// 觸發機率 (25%)
  static const double triggerProbability = 0.25;

  /// 是否需要紅點
  static const bool requireRedDot = true;

  /// Cell 冷卻時間 (小時)
  static const int cellCooldownHours = 24;

  /// 每日最大觸發次數
  static const int dailyMaxEvents = 3;

  /// 顯示時長 (毫秒)
  static const int displayDuration = 4000;

  /// 淡入時長 (毫秒)
  static const int fadeInDuration = 800;

  /// 淡出時長 (毫秒)
  static const int fadeOutDuration = 1200;

  /// 字體大小
  static const double fontSize = 16.0;

  /// 字體顏色 (ARGB)
  static const int fontColor = 0xE6FFFFFF;

  /// 文字陰影顏色 (ARGB)
  static const int textShadowColor = 0x80000000;

  /// 顯示位置 Y 比例 (螢幕高度的比例)
  static const double positionYRatio = 0.4;
}

// =============================================================================
// 推播系統配置
// =============================================================================

class PushConfig {
  PushConfig._();

  /// 每日最大推播數
  static const int maxDailyPush = 1;

  /// 最小推播間隔 (小時)
  static const int minIntervalHours = 20;

  /// 觸發類型
  static const String triggerType = 'first_unlock_today';

  /// 通知頻道 ID
  static const String channelId = 'fog_unlock';

  /// 通知頻道名稱
  static const String channelName = '地圖解鎖';

  /// 通知優先級
  static const String priority = 'default';

  /// 安靜時段開始 (小時)
  static const int quietHoursStart = 22;

  /// 安靜時段結束 (小時)
  static const int quietHoursEnd = 8;
}

// =============================================================================
// 地圖配置
// =============================================================================

class MapConfig {
  MapConfig._();

  /// 預設縮放等級
  static const double defaultZoom = 16.0;

  /// 最小縮放等級
  static const double minZoom = 10.0;

  /// 最大縮放等級
  static const double maxZoom = 19.0;

  /// 預設中心緯度 (台北)
  static const double defaultCenterLat = 25.0330;

  /// 預設中心經度 (台北)
  static const double defaultCenterLng = 121.5654;

  /// 地圖 Tile URL (暗色風格)
  static const String tileUrl =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
}
