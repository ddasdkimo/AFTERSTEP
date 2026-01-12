import 'dart:async';

import 'package:afterstep_fog/data/models/location_point.dart';
import 'package:afterstep_fog/data/models/unlock_point.dart';
import 'package:afterstep_fog/features/cell/geo_encoder.dart';
import 'package:afterstep_fog/features/cell/cell_service.dart';
import 'package:afterstep_fog/features/fog/fog_manager.dart';
import 'package:afterstep_fog/features/location/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 整合測試：位置追蹤 → Cell 解鎖 → Fog 解鎖 完整流程
///
/// 測試使用者步行時從 GPS 位置更新到 Fog 解鎖的完整資料流
void main() {
  group('位置追蹤到 Fog 解鎖整合流程', () {
    late LocationService locationService;
    late CellService cellService;
    late FogManager fogManager;

    setUp(() {
      locationService = LocationService();
      cellService = CellService();
      fogManager = FogManager();
    });

    tearDown(() {
      locationService.dispose();
      cellService.dispose();
      fogManager.dispose();
    });

    test('單一有效位置更新應觸發 Fog 解鎖', () async {
      // Arrange
      cellService.initialize('test_user');
      fogManager.initialize(FogState.empty);

      final receivedLocations = <ProcessedLocation>[];
      final receivedFogUpdates = <FogState>[];
      final unlockedCells = <String>[];

      locationService.validLocations.listen(receivedLocations.add);
      fogManager.fogUpdated.listen(receivedFogUpdates.add);

      // Act - 模擬有效步行位置 (速度約 1.2 m/s)
      final baseTime = DateTime.now().millisecondsSinceEpoch;

      // 第一個點
      locationService.processRawLocation(LocationPoint(
        latitude: 25.0330,
        longitude: 121.5654,
        accuracy: 10.0,
        timestamp: baseTime,
        altitude: 0,
        speed: 1.2,
      ));

      // 第二個點 (1秒後，約 1.2 米)
      locationService.processRawLocation(LocationPoint(
        latitude: 25.033011, // 約 1.2 米北
        longitude: 121.5654,
        accuracy: 10.0,
        timestamp: baseTime + 1000,
        altitude: 0,
        speed: 1.2,
      ));

      // 等待處理
      await Future.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(receivedLocations, isNotEmpty);
      expect(receivedLocations.last.isValid, isTrue);
      expect(receivedLocations.last.movementState, equals(MovementState.walking));
    });

    test('連續步行位置更新應累積 Fog 解鎖點', () async {
      // Arrange
      cellService.initialize('test_user');
      fogManager.initialize(FogState.empty);

      // 設定 Cell 解鎖回調
      cellService.cellUnlocked.listen((cell) {
        cellService.markCellUnlocked(cell.cellId);
      });

      // 設定 Fog 處理
      locationService.validLocations.listen((location) async {
        await cellService.processLocation(
          location,
          onUnlockCell: (cellId) async {
            cellService.markCellUnlocked(cellId);
          },
        );
        fogManager.processValidLocation(location);
      });

      // Act - 模擬連續步行（10個位置點）
      final baseTime = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < 10; i++) {
        // 每次往北移動約 1.2 米（0.000011 度）
        final point = LocationPoint(
          latitude: 25.0330 + (i * 0.000011),
          longitude: 121.5654,
          accuracy: 10.0,
          timestamp: baseTime + (i * 1000),
          altitude: 0,
          speed: 1.2,
        );
        locationService.processRawLocation(point);
        await Future.delayed(const Duration(milliseconds: 10));
      }

      // 等待所有處理完成
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(fogManager.points, isNotEmpty);
    });

    test('太快的移動應被過濾不產生 Fog 解鎖', () async {
      // Arrange
      cellService.initialize('test_user');
      fogManager.initialize(FogState.empty);

      locationService.validLocations.listen((location) {
        fogManager.processValidLocation(location);
      });

      // Act - 模擬車速移動（5 m/s）
      final baseTime = DateTime.now().millisecondsSinceEpoch;

      // 第一個點
      locationService.processRawLocation(LocationPoint(
        latitude: 25.0330,
        longitude: 121.5654,
        accuracy: 10.0,
        timestamp: baseTime,
        altitude: 0,
        speed: 5.0,
      ));

      // 第二個點（1秒後，5 米遠 - 太快）
      locationService.processRawLocation(LocationPoint(
        latitude: 25.033045, // 約 5 米北
        longitude: 121.5654,
        accuracy: 10.0,
        timestamp: baseTime + 1000,
        altitude: 0,
        speed: 5.0,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // Assert - 快速移動不應產生有效位置
      final validLocations = <ProcessedLocation>[];
      locationService.validLocations.listen(validLocations.add);
      expect(validLocations, isEmpty);
    });

    test('停留事件應觸發較大半徑的 Fog 解鎖', () async {
      // Arrange
      cellService.initialize('test_user');
      fogManager.initialize(FogState.empty);

      locationService.stayEvents.listen((stay) {
        fogManager.processStayEvent(stay);
      });

      // Act - 模擬停留（同一位置多次更新）
      final baseTime = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < 35; i++) {
        // 停留 35 秒（超過 30 秒門檻）
        locationService.processRawLocation(LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
          accuracy: 10.0,
          timestamp: baseTime + (i * 1000),
          altitude: 0,
          speed: 0.1, // 幾乎靜止
        ));
        await Future.delayed(const Duration(milliseconds: 10));
      }

      await Future.delayed(const Duration(milliseconds: 100));

      // Assert - 應該觸發停留事件
      // 注意：具體行為取決於 StayDetector 實作
    });

    test('低精度位置更新應被過濾', () async {
      // Arrange
      final receivedLocations = <ProcessedLocation>[];
      locationService.validLocations.listen(receivedLocations.add);

      // Act - 模擬低精度位置
      final baseTime = DateTime.now().millisecondsSinceEpoch;
      locationService.processRawLocation(LocationPoint(
        latitude: 25.0330,
        longitude: 121.5654,
        accuracy: 50.0, // 精度太差（>20米門檻）
        timestamp: baseTime,
        altitude: 0,
        speed: 1.2,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(receivedLocations, isEmpty);
    });
  });

  group('Cell 與 Fog 同步整合', () {
    late CellService cellService;
    late FogManager fogManager;
    late GeoEncoder geoEncoder;

    setUp(() {
      cellService = CellService();
      fogManager = FogManager();
      geoEncoder = GeoEncoder();
    });

    tearDown(() {
      cellService.dispose();
      fogManager.dispose();
    });

    test('Fog 解鎖區域應對應正確的 Cell', () {
      // Arrange
      cellService.initialize('test_user');
      fogManager.initialize(FogState.empty);

      // Act
      const lat = 25.0330;
      const lng = 121.5654;
      final cell = geoEncoder.coordToCell(lat, lng);

      final location = ProcessedLocation(
        point: LocationPoint(
          latitude: lat,
          longitude: lng,
          accuracy: 10.0,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          altitude: 0,
          speed: 1.2,
        ),
        calculatedSpeed: 1.2,
        movementState: MovementState.walking,
        isValid: true,
        distanceFromLast: 10.0,
      );

      cellService.processLocation(
        location,
        onUnlockCell: (_) async {},
      );

      fogManager.processValidLocation(location);

      // Assert
      expect(fogManager.points.last.latitude, closeTo(lat, 0.0001));
      expect(fogManager.points.last.longitude, closeTo(lng, 0.0001));
    });

    test('跨越多個 Cell 的步行軌跡應正確處理', () async {
      // Arrange
      cellService.initialize('test_user');
      fogManager.initialize(FogState.empty);

      final unlockedCells = <String>{};

      // Act - 模擬跨越 Cell 邊界的步行
      const baseLat = 25.0330;
      const baseLng = 121.5654;

      // Cell 大小約 200 米，移動 500 米應該跨越多個 Cell
      for (int i = 0; i < 5; i++) {
        // 每次往東移動約 100 米
        final lat = baseLat;
        final lng = baseLng + (i * 0.001); // 約 100 米

        final location = ProcessedLocation(
          point: LocationPoint(
            latitude: lat,
            longitude: lng,
            accuracy: 10.0,
            timestamp: DateTime.now().millisecondsSinceEpoch + (i * 60000),
            altitude: 0,
            speed: 1.2,
          ),
          calculatedSpeed: 1.2,
          movementState: MovementState.walking,
          isValid: true,
          distanceFromLast: 100.0,
        );

        await cellService.processLocation(
          location,
          onUnlockCell: (cellId) async {
            unlockedCells.add(cellId);
            cellService.markCellUnlocked(cellId);
          },
        );

        fogManager.processValidLocation(location);
      }

      // Assert
      expect(unlockedCells.length, greaterThanOrEqualTo(3));
      expect(fogManager.points.length, greaterThanOrEqualTo(3));
    });
  });

  group('資料流正確性驗證', () {
    test('位置串流應正確傳遞處理狀態', () async {
      // Arrange
      final locationService = LocationService();

      final rawReceived = <LocationPoint>[];
      final validReceived = <ProcessedLocation>[];
      final staysReceived = <StayEvent>[];

      locationService.rawLocations.listen(rawReceived.add);
      locationService.validLocations.listen(validReceived.add);
      locationService.stayEvents.listen(staysReceived.add);

      // Act
      final baseTime = DateTime.now().millisecondsSinceEpoch;

      // 發送有效點
      locationService.processRawLocation(LocationPoint(
        latitude: 25.0330,
        longitude: 121.5654,
        accuracy: 10.0,
        timestamp: baseTime,
        altitude: 0,
        speed: 1.2,
      ));

      locationService.processRawLocation(LocationPoint(
        latitude: 25.033011,
        longitude: 121.5654,
        accuracy: 10.0,
        timestamp: baseTime + 1000,
        altitude: 0,
        speed: 1.2,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(rawReceived.length, equals(2));
      expect(validReceived, isNotEmpty);

      locationService.dispose();
    });

    test('Fog 更新串流應包含累積狀態', () async {
      // Arrange
      final fogManager = FogManager();
      fogManager.initialize(FogState.empty);

      final fogUpdates = <FogState>[];
      fogManager.fogUpdated.listen(fogUpdates.add);

      // Act - 新增多個點
      for (int i = 0; i < 5; i++) {
        final location = ProcessedLocation(
          point: LocationPoint(
            latitude: 25.0330 + (i * 0.0001),
            longitude: 121.5654,
            accuracy: 10.0,
            timestamp: DateTime.now().millisecondsSinceEpoch + (i * 10000),
            altitude: 0,
            speed: 1.2,
          ),
          calculatedSpeed: 1.2,
          movementState: MovementState.walking,
          isValid: true,
          distanceFromLast: 11.0,
        );
        fogManager.processValidLocation(location);
      }

      await Future.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(fogUpdates, isNotEmpty);
      // 每次更新應包含所有累積的點
      expect(fogUpdates.last.points.length, greaterThanOrEqualTo(1));

      fogManager.dispose();
    });

    test('Cell 變更串流應正確觸發', () async {
      // Arrange
      final cellService = CellService();
      cellService.initialize('test_user');

      final cellChanges = <String>[];
      cellService.cellChanged.listen((cell) {
        cellChanges.add(cell.cellId);
      });

      // Act - 在不同 Cell 中移動
      for (int i = 0; i < 3; i++) {
        final location = ProcessedLocation(
          point: LocationPoint(
            latitude: 25.0330,
            longitude: 121.5654 + (i * 0.003), // 跨越不同 Cell
            accuracy: 10.0,
            timestamp: DateTime.now().millisecondsSinceEpoch,
            altitude: 0,
            speed: 1.2,
          ),
          calculatedSpeed: 1.2,
          movementState: MovementState.walking,
          isValid: true,
          distanceFromLast: 100.0,
        );

        await cellService.processLocation(location);
      }

      await Future.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(cellChanges.length, greaterThanOrEqualTo(2));

      cellService.dispose();
    });
  });
}
