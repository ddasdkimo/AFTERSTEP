import 'package:equatable/equatable.dart';

/// 解鎖類型枚舉
enum UnlockType {
  /// 步行解鎖
  walk,

  /// 停留解鎖
  stay,
}

/// 解鎖點
///
/// 表示地圖上一個已解鎖的區域點。
class UnlockPoint extends Equatable {
  /// 建立解鎖點
  const UnlockPoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.timestamp,
    required this.type,
    this.synced = false,
  });

  /// 唯一識別符
  final String id;

  /// 緯度
  final double latitude;

  /// 經度
  final double longitude;

  /// 解鎖半徑 (公尺)
  final double radius;

  /// 時間戳記 (毫秒)
  final int timestamp;

  /// 解鎖類型
  final UnlockType type;

  /// 是否已同步到 Firebase
  final bool synced;

  @override
  List<Object?> get props => [
        id,
        latitude,
        longitude,
        radius,
        timestamp,
        type,
        synced,
      ];

  /// 從 Map 建立
  factory UnlockPoint.fromMap(Map<String, dynamic> map) {
    return UnlockPoint(
      id: map['id'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radius: (map['radius'] as num).toDouble(),
      timestamp: map['timestamp'] as int,
      type: UnlockType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => UnlockType.walk,
      ),
      synced: map['synced'] as bool? ?? false,
    );
  }

  /// 轉換為 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'timestamp': timestamp,
      'type': type.name,
      'synced': synced ? 1 : 0,
    };
  }

  /// 複製並修改
  UnlockPoint copyWith({
    String? id,
    double? latitude,
    double? longitude,
    double? radius,
    int? timestamp,
    UnlockType? type,
    bool? synced,
  }) {
    return UnlockPoint(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      synced: synced ?? this.synced,
    );
  }
}

/// 解鎖軌跡
///
/// 表示一段連續的解鎖路徑。
class UnlockPath extends Equatable {
  /// 建立解鎖軌跡
  const UnlockPath({
    required this.id,
    required this.points,
    required this.width,
    required this.timestamp,
    this.synced = false,
  });

  /// 唯一識別符
  final String id;

  /// 軌跡點列表 [(lat, lng), ...]
  final List<({double lat, double lng})> points;

  /// 軌跡寬度 (公尺)
  final double width;

  /// 時間戳記 (毫秒)
  final int timestamp;

  /// 是否已同步到 Firebase
  final bool synced;

  @override
  List<Object?> get props => [id, points, width, timestamp, synced];

  /// 從 Map 建立
  factory UnlockPath.fromMap(Map<String, dynamic> map) {
    final pointsData = map['points'] as String;
    final points = _decodePoints(pointsData);

    return UnlockPath(
      id: map['id'] as String,
      points: points,
      width: (map['width'] as num).toDouble(),
      timestamp: map['timestamp'] as int,
      synced: map['synced'] as bool? ?? false,
    );
  }

  /// 轉換為 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'points': _encodePoints(points),
      'width': width,
      'timestamp': timestamp,
      'synced': synced ? 1 : 0,
    };
  }

  /// 複製並修改
  UnlockPath copyWith({
    String? id,
    List<({double lat, double lng})>? points,
    double? width,
    int? timestamp,
    bool? synced,
  }) {
    return UnlockPath(
      id: id ?? this.id,
      points: points ?? this.points,
      width: width ?? this.width,
      timestamp: timestamp ?? this.timestamp,
      synced: synced ?? this.synced,
    );
  }

  /// 編碼軌跡點 (使用 delta encoding)
  static String _encodePoints(List<({double lat, double lng})> points) {
    if (points.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.write('${(points[0].lat * 1e6).round()},${(points[0].lng * 1e6).round()}');

    for (var i = 1; i < points.length; i++) {
      final dLat = ((points[i].lat - points[i - 1].lat) * 1e6).round();
      final dLng = ((points[i].lng - points[i - 1].lng) * 1e6).round();
      buffer.write(';$dLat,$dLng');
    }

    return buffer.toString();
  }

  /// 解碼軌跡點
  static List<({double lat, double lng})> _decodePoints(String encoded) {
    if (encoded.isEmpty) return [];

    final points = <({double lat, double lng})>[];
    final parts = encoded.split(';');

    final first = parts[0].split(',');
    var lat = int.parse(first[0]) / 1e6;
    var lng = int.parse(first[1]) / 1e6;
    points.add((lat: lat, lng: lng));

    for (var i = 1; i < parts.length; i++) {
      final delta = parts[i].split(',');
      lat += int.parse(delta[0]) / 1e6;
      lng += int.parse(delta[1]) / 1e6;
      points.add((lat: lat, lng: lng));
    }

    return points;
  }
}

/// Fog 狀態
///
/// 包含所有解鎖點和軌跡的完整狀態。
class FogState extends Equatable {
  /// 建立 Fog 狀態
  const FogState({
    required this.points,
    required this.paths,
    this.totalUnlockedArea = 0.0,
    this.lastSyncTime = 0,
  });

  /// 空狀態
  static const empty = FogState(points: [], paths: []);

  /// 所有解鎖點
  final List<UnlockPoint> points;

  /// 所有解鎖軌跡
  final List<UnlockPath> paths;

  /// 總解鎖面積 (平方公尺)
  final double totalUnlockedArea;

  /// 最後同步時間 (毫秒)
  final int lastSyncTime;

  @override
  List<Object?> get props => [
        points,
        paths,
        totalUnlockedArea,
        lastSyncTime,
      ];

  /// 複製並修改
  FogState copyWith({
    List<UnlockPoint>? points,
    List<UnlockPath>? paths,
    double? totalUnlockedArea,
    int? lastSyncTime,
  }) {
    return FogState(
      points: points ?? this.points,
      paths: paths ?? this.paths,
      totalUnlockedArea: totalUnlockedArea ?? this.totalUnlockedArea,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}
