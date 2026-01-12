import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/models/cell.dart';
import '../../data/models/unlock_point.dart';

/// 本地儲存服務
///
/// 使用 SQLite 儲存 Fog 資料和 Cell 狀態，支援離線運作。
class StorageService {
  Database? _db;

  /// 資料庫名稱
  static const String _dbName = 'fog_data.db';

  /// 資料庫版本
  static const int _dbVersion = 1;

  /// 是否已初始化
  bool get isInitialized => _db != null;

  /// 初始化資料庫
  Future<void> initialize() async {
    if (_db != null) return;

    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 建立資料表
  Future<void> _onCreate(Database db, int version) async {
    // Fog 解鎖點
    await db.execute('''
      CREATE TABLE fog_points (
        id TEXT PRIMARY KEY,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radius REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        type TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Fog 軌跡
    await db.execute('''
      CREATE TABLE fog_paths (
        id TEXT PRIMARY KEY,
        points TEXT NOT NULL,
        width REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Cell 狀態
    await db.execute('''
      CREATE TABLE user_cells (
        cell_id TEXT PRIMARY KEY,
        unlocked INTEGER DEFAULT 0,
        unlocked_at INTEGER,
        last_visit INTEGER,
        micro_event_cooldown INTEGER
      )
    ''');

    // 建立索引
    await db.execute('''
      CREATE INDEX idx_points_location
      ON fog_points(latitude, longitude)
    ''');

    await db.execute('''
      CREATE INDEX idx_points_synced
      ON fog_points(synced)
    ''');

    await db.execute('''
      CREATE INDEX idx_paths_synced
      ON fog_paths(synced)
    ''');

    await db.execute('''
      CREATE INDEX idx_cells_unlocked
      ON user_cells(unlocked)
    ''');
  }

  /// 資料庫升級
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 未來版本升級時使用
  }

  // ==================== Fog Points ====================

  /// 儲存解鎖點
  Future<void> savePoint(UnlockPoint point) async {
    await _db?.insert(
      'fog_points',
      point.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 批次儲存解鎖點
  Future<void> savePoints(List<UnlockPoint> points) async {
    final batch = _db?.batch();
    for (final point in points) {
      batch?.insert(
        'fog_points',
        point.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch?.commit(noResult: true);
  }

  /// 載入所有解鎖點
  Future<List<UnlockPoint>> loadAllPoints() async {
    final maps = await _db?.query('fog_points') ?? [];
    return maps.map((m) => UnlockPoint.fromMap(m)).toList();
  }

  /// 載入未同步的解鎖點
  Future<List<UnlockPoint>> loadUnsyncedPoints() async {
    final maps = await _db?.query(
          'fog_points',
          where: 'synced = ?',
          whereArgs: [0],
        ) ??
        [];
    return maps.map((m) => UnlockPoint.fromMap(m)).toList();
  }

  /// 標記解鎖點為已同步
  Future<void> markPointsSynced(List<String> ids) async {
    final batch = _db?.batch();
    for (final id in ids) {
      batch?.update(
        'fog_points',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch?.commit(noResult: true);
  }

  // ==================== Fog Paths ====================

  /// 儲存軌跡
  Future<void> savePath(UnlockPath path) async {
    await _db?.insert(
      'fog_paths',
      path.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 批次儲存軌跡
  Future<void> savePaths(List<UnlockPath> paths) async {
    final batch = _db?.batch();
    for (final path in paths) {
      batch?.insert(
        'fog_paths',
        path.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch?.commit(noResult: true);
  }

  /// 載入所有軌跡
  Future<List<UnlockPath>> loadAllPaths() async {
    final maps = await _db?.query('fog_paths') ?? [];
    return maps.map((m) => UnlockPath.fromMap(m)).toList();
  }

  /// 載入未同步的軌跡
  Future<List<UnlockPath>> loadUnsyncedPaths() async {
    final maps = await _db?.query(
          'fog_paths',
          where: 'synced = ?',
          whereArgs: [0],
        ) ??
        [];
    return maps.map((m) => UnlockPath.fromMap(m)).toList();
  }

  /// 標記軌跡為已同步
  Future<void> markPathsSynced(List<String> ids) async {
    final batch = _db?.batch();
    for (final id in ids) {
      batch?.update(
        'fog_paths',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch?.commit(noResult: true);
  }

  // ==================== User Cells ====================

  /// 儲存 Cell 狀態
  Future<void> saveCellState(UserCellState state) async {
    await _db?.insert(
      'user_cells',
      state.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 批次儲存 Cell 狀態
  Future<void> saveCellStates(List<UserCellState> states) async {
    final batch = _db?.batch();
    for (final state in states) {
      batch?.insert(
        'user_cells',
        state.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch?.commit(noResult: true);
  }

  /// 載入指定 Cell 的狀態
  Future<UserCellState?> loadCellState(String cellId) async {
    final maps = await _db?.query(
      'user_cells',
      where: 'cell_id = ?',
      whereArgs: [cellId],
    );

    if (maps == null || maps.isEmpty) return null;
    return UserCellState.fromMap(maps.first);
  }

  /// 載入所有已解鎖的 Cell
  Future<List<UserCellState>> loadUnlockedCells() async {
    final maps = await _db?.query(
          'user_cells',
          where: 'unlocked = ?',
          whereArgs: [1],
        ) ??
        [];
    return maps.map((m) => UserCellState.fromMap(m)).toList();
  }

  /// 載入所有 Cell 狀態
  Future<List<UserCellState>> loadAllCellStates() async {
    final maps = await _db?.query('user_cells') ?? [];
    return maps.map((m) => UserCellState.fromMap(m)).toList();
  }

  // ==================== Fog State ====================

  /// 載入完整 Fog 狀態
  Future<FogState> loadFogState() async {
    final points = await loadAllPoints();
    final paths = await loadAllPaths();

    return FogState(
      points: points,
      paths: paths,
      totalUnlockedArea: 0,
      lastSyncTime: 0,
    );
  }

  /// 儲存完整 Fog 狀態
  Future<void> saveFogState(FogState state) async {
    await savePoints(state.points);
    await savePaths(state.paths);
  }

  // ==================== Utilities ====================

  /// 取得統計資料
  Future<Map<String, int>> getStatistics() async {
    final pointCountResult = await _db?.rawQuery('SELECT COUNT(*) FROM fog_points');
    final pointCount = Sqflite.firstIntValue(pointCountResult ?? []) ?? 0;

    final pathCountResult = await _db?.rawQuery('SELECT COUNT(*) FROM fog_paths');
    final pathCount = Sqflite.firstIntValue(pathCountResult ?? []) ?? 0;

    final unlockedCellCountResult =
        await _db?.rawQuery('SELECT COUNT(*) FROM user_cells WHERE unlocked = 1');
    final unlockedCellCount = Sqflite.firstIntValue(unlockedCellCountResult ?? []) ?? 0;

    final unsyncedPointCountResult =
        await _db?.rawQuery('SELECT COUNT(*) FROM fog_points WHERE synced = 0');
    final unsyncedPointCount = Sqflite.firstIntValue(unsyncedPointCountResult ?? []) ?? 0;

    final unsyncedPathCountResult =
        await _db?.rawQuery('SELECT COUNT(*) FROM fog_paths WHERE synced = 0');
    final unsyncedPathCount = Sqflite.firstIntValue(unsyncedPathCountResult ?? []) ?? 0;

    return {
      'points': pointCount,
      'paths': pathCount,
      'unlocked_cells': unlockedCellCount,
      'unsynced_points': unsyncedPointCount,
      'unsynced_paths': unsyncedPathCount,
    };
  }

  /// 清空所有資料
  Future<void> clearAll() async {
    await _db?.delete('fog_points');
    await _db?.delete('fog_paths');
    await _db?.delete('user_cells');
  }

  /// 關閉資料庫
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
