import 'package:equatable/equatable.dart';

/// Cell 邊界
class CellBounds extends Equatable {
  /// 建立 Cell 邊界
  const CellBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  /// 北邊界緯度
  final double north;

  /// 南邊界緯度
  final double south;

  /// 東邊界經度
  final double east;

  /// 西邊界經度
  final double west;

  @override
  List<Object?> get props => [north, south, east, west];
}

/// Cell 網格單元
///
/// 表示地圖上的一個網格單元，用於追蹤活動和解鎖狀態。
class Cell extends Equatable {
  /// 建立 Cell
  const Cell({
    required this.cellId,
    required this.latIndex,
    required this.lngIndex,
    required this.centerLat,
    required this.centerLng,
    required this.bounds,
  });

  /// Cell 唯一識別符 "lat_index:lng_index"
  final String cellId;

  /// 緯度索引
  final int latIndex;

  /// 經度索引
  final int lngIndex;

  /// 中心緯度
  final double centerLat;

  /// 中心經度
  final double centerLng;

  /// 邊界
  final CellBounds bounds;

  @override
  List<Object?> get props => [
        cellId,
        latIndex,
        lngIndex,
        centerLat,
        centerLng,
        bounds,
      ];

  /// 從 Map 建立
  factory Cell.fromMap(Map<String, dynamic> map) {
    return Cell(
      cellId: map['cell_id'] as String,
      latIndex: map['lat_index'] as int,
      lngIndex: map['lng_index'] as int,
      centerLat: (map['center_lat'] as num).toDouble(),
      centerLng: (map['center_lng'] as num).toDouble(),
      bounds: CellBounds(
        north: (map['bounds_north'] as num).toDouble(),
        south: (map['bounds_south'] as num).toDouble(),
        east: (map['bounds_east'] as num).toDouble(),
        west: (map['bounds_west'] as num).toDouble(),
      ),
    );
  }

  /// 轉換為 Map
  Map<String, dynamic> toMap() {
    return {
      'cell_id': cellId,
      'lat_index': latIndex,
      'lng_index': lngIndex,
      'center_lat': centerLat,
      'center_lng': centerLng,
      'bounds_north': bounds.north,
      'bounds_south': bounds.south,
      'bounds_east': bounds.east,
      'bounds_west': bounds.west,
    };
  }
}

/// 使用者 Cell 狀態
///
/// 記錄使用者對某個 Cell 的狀態（是否解鎖、上次訪問等）。
class UserCellState extends Equatable {
  /// 建立使用者 Cell 狀態
  const UserCellState({
    required this.cellId,
    required this.unlocked,
    this.unlockedAt,
    this.lastVisit,
    this.microEventCooldown,
  });

  /// Cell ID
  final String cellId;

  /// 是否已解鎖
  final bool unlocked;

  /// 解鎖時間 (毫秒)
  final int? unlockedAt;

  /// 上次訪問時間 (毫秒)
  final int? lastVisit;

  /// 微事件冷卻時間 (毫秒)
  final int? microEventCooldown;

  @override
  List<Object?> get props => [
        cellId,
        unlocked,
        unlockedAt,
        lastVisit,
        microEventCooldown,
      ];

  /// 從 Map 建立
  factory UserCellState.fromMap(Map<String, dynamic> map) {
    return UserCellState(
      cellId: map['cell_id'] as String,
      unlocked: map['unlocked'] as bool? ?? false,
      unlockedAt: map['unlocked_at'] as int?,
      lastVisit: map['last_visit'] as int?,
      microEventCooldown: map['micro_event_cooldown'] as int?,
    );
  }

  /// 轉換為 Map
  Map<String, dynamic> toMap() {
    return {
      'cell_id': cellId,
      'unlocked': unlocked,
      'unlocked_at': unlockedAt,
      'last_visit': lastVisit,
      'micro_event_cooldown': microEventCooldown,
    };
  }

  /// 複製並修改
  UserCellState copyWith({
    String? cellId,
    bool? unlocked,
    int? unlockedAt,
    int? lastVisit,
    int? microEventCooldown,
  }) {
    return UserCellState(
      cellId: cellId ?? this.cellId,
      unlocked: unlocked ?? this.unlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      lastVisit: lastVisit ?? this.lastVisit,
      microEventCooldown: microEventCooldown ?? this.microEventCooldown,
    );
  }
}

/// Cell 活動記錄
///
/// 用於紅點系統，記錄 Cell 的最後活動時間。
class CellActivity extends Equatable {
  /// 建立 Cell 活動記錄
  const CellActivity({
    required this.cellId,
    required this.lastActivityTime,
  });

  /// Cell ID
  final String cellId;

  /// 最後活動時間 (毫秒)
  final int lastActivityTime;

  @override
  List<Object?> get props => [cellId, lastActivityTime];

  /// 從 Map 建立
  factory CellActivity.fromMap(Map<String, dynamic> map) {
    return CellActivity(
      cellId: map['cell_id'] as String,
      lastActivityTime: map['last_activity_time'] as int,
    );
  }

  /// 轉換為 Map
  Map<String, dynamic> toMap() {
    return {
      'cell_id': cellId,
      'last_activity_time': lastActivityTime,
    };
  }
}
