import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../data/models/cell.dart';
import '../../data/models/unlock_point.dart';

/// Firebase 服務
///
/// 封裝 Firebase 相關操作，包括身份驗證、Firestore 資料同步。
class FirebaseService {
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;

  /// 當前使用者 ID
  String? get userId => _auth?.currentUser?.uid;

  /// 是否已登入
  bool get isSignedIn => _auth?.currentUser != null;

  /// 初始化 Firebase
  Future<void> initialize() async {
    await Firebase.initializeApp();
    _firestore = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;

    // 啟用離線持久化
    _firestore?.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  /// 匿名登入
  Future<String?> signInAnonymously() async {
    try {
      final result = await _auth?.signInAnonymously();
      return result?.user?.uid;
    } catch (e) {
      return null;
    }
  }

  /// 登出
  Future<void> signOut() async {
    await _auth?.signOut();
  }

  // ==================== Cell 活動（紅點用）====================

  /// 記錄 Cell 活動
  Future<void> recordCellActivity(String cellId) async {
    if (userId == null) return;

    await _firestore?.collection('cells').doc(cellId).set({
      'last_activity_time': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 批次取得 Cell 活動
  Future<List<CellActivity>> getCellActivities(List<String> cellIds) async {
    if (cellIds.isEmpty) return [];

    final result = <CellActivity>[];

    // Firestore 限制 whereIn 最多 10 個元素
    final chunks = _chunkList(cellIds, 10);

    for (final chunk in chunks) {
      final snapshot = await _firestore
          ?.collection('cells')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      if (snapshot != null) {
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final timestamp = data['last_activity_time'] as Timestamp?;
          if (timestamp != null) {
            result.add(CellActivity(
              cellId: doc.id,
              lastActivityTime: timestamp.millisecondsSinceEpoch,
            ));
          }
        }
      }
    }

    return result;
  }

  // ==================== 使用者 Cell 狀態 ====================

  /// 解鎖 Cell
  Future<void> unlockCell(String cellId) async {
    if (userId == null) return;

    await _firestore
        ?.collection('users')
        .doc(userId)
        .collection('cells')
        .doc(cellId)
        .set({
      'cell_id': cellId,
      'unlocked': true,
      'unlocked_at': FieldValue.serverTimestamp(),
      'last_visit': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 取得使用者已解鎖的 Cell
  Future<List<UserCellState>> getUnlockedCells() async {
    if (userId == null) return [];

    final snapshot = await _firestore
        ?.collection('users')
        .doc(userId)
        .collection('cells')
        .where('unlocked', isEqualTo: true)
        .get();

    if (snapshot == null) return [];

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return UserCellState(
        cellId: doc.id,
        unlocked: data['unlocked'] as bool? ?? false,
        unlockedAt: (data['unlocked_at'] as Timestamp?)?.millisecondsSinceEpoch,
        lastVisit: (data['last_visit'] as Timestamp?)?.millisecondsSinceEpoch,
      );
    }).toList();
  }

  // ==================== Fog 資料同步 ====================

  /// 同步 Fog 資料到 Firestore
  Future<void> syncFogData(
    List<UnlockPoint> points,
    List<UnlockPath> paths,
  ) async {
    if (userId == null) return;
    if (points.isEmpty && paths.isEmpty) return;

    final batch = _firestore?.batch();
    final userFogRef =
        _firestore?.collection('users').doc(userId).collection('fog');

    // 同步解鎖點
    for (final point in points) {
      final docRef = userFogRef?.doc('point_${point.id}');
      if (docRef != null) {
        batch?.set(docRef, {
          'type': 'point',
          'latitude': point.latitude,
          'longitude': point.longitude,
          'radius': point.radius,
          'timestamp': Timestamp.fromMillisecondsSinceEpoch(point.timestamp),
          'unlock_type': point.type.name,
        });
      }
    }

    // 同步軌跡
    for (final path in paths) {
      final docRef = userFogRef?.doc('path_${path.id}');
      if (docRef != null) {
        batch?.set(docRef, {
          'type': 'path',
          'points': _compressPoints(path.points),
          'width': path.width,
          'timestamp': Timestamp.fromMillisecondsSinceEpoch(path.timestamp),
        });
      }
    }

    await batch?.commit();
  }

  /// 從 Firestore 載入 Fog 資料
  Future<FogState> loadFogData() async {
    if (userId == null) return FogState.empty;

    final snapshot = await _firestore
        ?.collection('users')
        .doc(userId)
        .collection('fog')
        .get();

    if (snapshot == null) return FogState.empty;

    final points = <UnlockPoint>[];
    final paths = <UnlockPath>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final type = data['type'] as String?;

      if (type == 'point') {
        points.add(UnlockPoint(
          id: doc.id.replaceFirst('point_', ''),
          latitude: (data['latitude'] as num).toDouble(),
          longitude: (data['longitude'] as num).toDouble(),
          radius: (data['radius'] as num).toDouble(),
          timestamp: (data['timestamp'] as Timestamp).millisecondsSinceEpoch,
          type: UnlockType.values.firstWhere(
            (t) => t.name == data['unlock_type'],
            orElse: () => UnlockType.walk,
          ),
          synced: true,
        ));
      } else if (type == 'path') {
        paths.add(UnlockPath(
          id: doc.id.replaceFirst('path_', ''),
          points: _decompressPoints(data['points'] as String? ?? ''),
          width: (data['width'] as num).toDouble(),
          timestamp: (data['timestamp'] as Timestamp).millisecondsSinceEpoch,
          synced: true,
        ));
      }
    }

    return FogState(
      points: points,
      paths: paths,
      totalUnlockedArea: 0,
      lastSyncTime: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ==================== FCM Token ====================

  /// 更新 FCM Token
  Future<void> updateFcmToken(String token) async {
    if (userId == null) return;

    await _firestore?.collection('users').doc(userId).set({
      'fcm_token': token,
      'fcm_token_updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ==================== 工具方法 ====================

  /// 壓縮軌跡點（Delta Encoding）
  String _compressPoints(List<({double lat, double lng})> points) {
    if (points.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.write(
        '${(points[0].lat * 1e6).round()},${(points[0].lng * 1e6).round()}');

    for (var i = 1; i < points.length; i++) {
      final dLat = ((points[i].lat - points[i - 1].lat) * 1e6).round();
      final dLng = ((points[i].lng - points[i - 1].lng) * 1e6).round();
      buffer.write(';$dLat,$dLng');
    }

    return buffer.toString();
  }

  /// 解壓縮軌跡點
  List<({double lat, double lng})> _decompressPoints(String encoded) {
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

  /// 分割列表
  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      final end = (i + chunkSize < list.length) ? i + chunkSize : list.length;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }
}
