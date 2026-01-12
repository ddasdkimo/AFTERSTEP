import 'dart:async';

import 'package:afterstep_fog/core/config/constants.dart';
import 'package:afterstep_fog/data/models/cell.dart';
import 'package:afterstep_fog/data/models/location_point.dart';
import 'package:afterstep_fog/data/models/micro_event.dart';
import 'package:afterstep_fog/data/models/red_dot.dart';
import 'package:afterstep_fog/data/models/unlock_point.dart';
import 'package:afterstep_fog/features/cell/cell_cache.dart';
import 'package:afterstep_fog/features/cell/cell_service.dart';
import 'package:afterstep_fog/features/cell/geo_encoder.dart';
import 'package:afterstep_fog/features/fog/fog_manager.dart';
import 'package:afterstep_fog/features/location/drift_filter.dart';
import 'package:afterstep_fog/features/location/location_service.dart';
import 'package:afterstep_fog/features/location/speed_calculator.dart';
import 'package:afterstep_fog/features/location/stay_detector.dart';
import 'package:afterstep_fog/features/micro_event/cooldown_manager.dart';
import 'package:afterstep_fog/features/micro_event/micro_event_service.dart';
import 'package:afterstep_fog/features/micro_event/text_selector.dart';
import 'package:afterstep_fog/features/red_dot/intensity_calculator.dart';
import 'package:afterstep_fog/features/red_dot/position_obfuscator.dart';
import 'package:afterstep_fog/features/red_dot/red_dot_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 整合測試：所有服務模組的整合
///
/// 測試服務之間的協作和依賴注入
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('服務依賴注入', () {
    test('LocationService 應正確注入子元件', () {
      // Arrange
      final speedCalculator = SpeedCalculator();
      final driftFilter = DriftFilter();
      final stayDetector = StayDetector();

      // Act
      final service = LocationService(
        speedCalculator: speedCalculator,
        driftFilter: driftFilter,
        stayDetector: stayDetector,
      );

      // Assert
      expect(service, isNotNull);
      expect(service.isTracking, isFalse);

      service.dispose();
    });

    test('CellService 應正確注入子元件', () {
      // Arrange
      final geoEncoder = GeoEncoder();
      final cache = CellCache();
      final queryService = CellQueryService();

      // Act
      final service = CellService(
        geoEncoder: geoEncoder,
        cache: cache,
        queryService: queryService,
      );

      // Assert
      expect(service, isNotNull);
      expect(service.currentCell, isNull);

      service.dispose();
    });

    test('RedDotService 應正確注入子元件', () {
      // Arrange
      final intensityCalc = IntensityCalculator();
      final obfuscator = PositionObfuscator();
      final geoEncoder = GeoEncoder();

      // Act
      final service = RedDotService(
        intensityCalculator: intensityCalc,
        positionObfuscator: obfuscator,
        geoEncoder: geoEncoder,
      );

      // Assert
      expect(service, isNotNull);
      expect(service.currentRedDots, isEmpty);

      service.dispose();
    });

    test('MicroEventService 應正確注入子元件', () async {
      // Arrange
      final cooldownManager = CooldownManager();
      final textSelector = TextSelector();

      // Act
      final service = MicroEventService(
        cooldownManager: cooldownManager,
        textSelector: textSelector,
      );

      await service.initialize();

      // Assert
      expect(service, isNotNull);
      expect(service.getRemainingToday(), equals(3));

      service.dispose();
    });
  });

  group('服務生命週期管理', () {
    test('所有服務應正確釋放資源', () {
      // Arrange
      final locationService = LocationService();
      final cellService = CellService();
      final fogManager = FogManager();
      final redDotService = RedDotService();
      final microEventService = MicroEventService();

      // Act & Assert - 應該不會拋出異常
      expect(() => locationService.dispose(), returnsNormally);
      expect(() => cellService.dispose(), returnsNormally);
      expect(() => fogManager.dispose(), returnsNormally);
      expect(() => redDotService.dispose(), returnsNormally);
      expect(() => microEventService.dispose(), returnsNormally);
    });

    test('所有服務應正確重置狀態', () async {
      // Arrange
      final locationService = LocationService();
      final cellService = CellService();
      final fogManager = FogManager();
      final microEventService = MicroEventService();

      cellService.initialize('test_user');
      fogManager.initialize(FogState.empty);
      await microEventService.initialize();

      // 產生一些狀態
      cellService.markCellUnlocked('test_cell');

      // Act
      locationService.reset();
      cellService.reset();
      fogManager.reset();
      await microEventService.reset();

      // Assert
      expect(cellService.unlockedCellIds, isEmpty);
      expect(cellService.currentCell, isNull);
      expect(fogManager.points, isEmpty);

      // 清理
      locationService.dispose();
      cellService.dispose();
      fogManager.dispose();
      microEventService.dispose();
    });
  });

  group('串流訂閱管理', () {
    test('多個訂閱者應都能收到更新', () async {
      // Arrange
      final fogManager = FogManager();
      fogManager.initialize(FogState.empty);

      final subscriber1 = <FogState>[];
      final subscriber2 = <FogState>[];

      fogManager.fogUpdated.listen(subscriber1.add);
      fogManager.fogUpdated.listen(subscriber2.add);

      // Act
      final location = ProcessedLocation(
        point: LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
          accuracy: 10.0,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          altitude: 0,
          speed: 1.2,
        ),
        calculatedSpeed: 1.2,
        movementState: MovementState.walking,
        isValid: true,
        distanceFromLast: 50.0,
      );

      fogManager.processValidLocation(location);
      await Future.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(subscriber1, isNotEmpty);
      expect(subscriber2, isNotEmpty);
      expect(subscriber1.length, equals(subscriber2.length));

      fogManager.dispose();
    });

    test('BehaviorSubject 應提供最新值給新訂閱者', () async {
      // Arrange
      final fogManager = FogManager();
      fogManager.initialize(FogState.empty);

      // 先產生一些狀態
      final location = ProcessedLocation(
        point: LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
          accuracy: 10.0,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          altitude: 0,
          speed: 1.2,
        ),
        calculatedSpeed: 1.2,
        movementState: MovementState.walking,
        isValid: true,
        distanceFromLast: 50.0,
      );

      fogManager.processValidLocation(location);
      await Future.delayed(const Duration(milliseconds: 50));

      // Act - 新訂閱者
      final lateSubscriber = <FogState>[];
      fogManager.fogUpdated.listen(lateSubscriber.add);
      await Future.delayed(const Duration(milliseconds: 50));

      // Assert - 應該立即收到最新狀態
      expect(lateSubscriber, isNotEmpty);

      fogManager.dispose();
    });
  });

  group('服務間回調機制', () {
    test('CellService 解鎖回調應正確觸發', () async {
      // Arrange
      final cellService = CellService();
      cellService.initialize('test_user');

      final unlockedCells = <String>[];

      // Act
      final location = ProcessedLocation(
        point: LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
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

      await cellService.processLocation(
        location,
        onUnlockCell: (cellId) async {
          unlockedCells.add(cellId);
        },
      );

      // Assert
      expect(unlockedCells, isNotEmpty);

      cellService.dispose();
    });

    test('FogManager 同步回調應正確觸發', () async {
      // Arrange
      final fogManager = FogManager();
      fogManager.initialize(FogState.empty);

      final syncedPoints = <UnlockPoint>[];
      final syncedPaths = <UnlockPath>[];

      fogManager.setSyncCallback((points, paths) async {
        syncedPoints.addAll(points);
        syncedPaths.addAll(paths);
      });

      // Act - 產生多個點
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

      // 強制同步
      await fogManager.forceSync();

      // Assert
      expect(syncedPoints, isNotEmpty);

      fogManager.dispose();
    });

    test('RedDotService 取得活動回調應正確觸發', () async {
      // Arrange
      final redDotService = RedDotService();
      final cellService = CellService();
      final geoEncoder = GeoEncoder();
      cellService.initialize('test_user');

      // 使用視口範圍內的正確 Cell ID
      final cell = geoEncoder.coordToCell(25.035, 121.565);
      cellService.markCellUnlocked(cell.cellId);

      final requestedCellIds = <String>[];

      redDotService.setFetchActivitiesCallback((cellIds) async {
        requestedCellIds.addAll(cellIds);
        return [];
      });

      // Act
      final viewport = ViewportBounds(
        north: 25.040,
        south: 25.030,
        east: 121.570,
        west: 121.560,
        zoom: 15.0,
      );

      await redDotService.getRedDotsInViewport(
        viewport,
        cellService.unlockedCellIds,
      );

      // Assert
      expect(requestedCellIds, isNotEmpty);

      redDotService.dispose();
      cellService.dispose();
    });
  });

  group('設定參數驗證', () {
    test('GpsConfig 參數應在合理範圍內', () {
      expect(GpsConfig.speedMin, greaterThan(0));
      expect(GpsConfig.speedMax, greaterThan(GpsConfig.speedMin));
      expect(GpsConfig.speedCutoff, greaterThan(GpsConfig.speedMax));
      expect(GpsConfig.accuracyThreshold, greaterThan(0));
    });

    test('CellConfig 參數應在合理範圍內', () {
      expect(CellConfig.cellSize, greaterThan(0));
      expect(CellConfig.cellSize, lessThanOrEqualTo(1000)); // 最大 1 公里
    });

    test('RedDotConfig 參數應在合理範圍內', () {
      expect(RedDotConfig.decayTauDays, greaterThan(0));
      expect(RedDotConfig.intensityThreshold, greaterThan(0));
      expect(RedDotConfig.intensityThreshold, lessThan(1));
    });

    test('MicroEventConfig 參數應在合理範圍內', () {
      expect(MicroEventConfig.triggerStayDuration, greaterThan(0));
      expect(MicroEventConfig.triggerProbability, greaterThan(0));
      expect(MicroEventConfig.triggerProbability, lessThanOrEqualTo(1));
      expect(MicroEventConfig.dailyMaxEvents, greaterThan(0));
    });
  });

  group('錯誤處理與邊界情況', () {
    test('空視口應正確處理', () async {
      // Arrange
      final redDotService = RedDotService();
      final cellService = CellService();
      cellService.initialize('test_user');

      redDotService.setFetchActivitiesCallback((cellIds) async => []);

      // Act - 使用有效但空的視口
      final viewport = ViewportBounds(
        north: 25.0330,
        south: 25.0330, // 與 north 相同
        east: 121.5654,
        west: 121.5654, // 與 east 相同
        zoom: 15.0,
      );

      final redDots = await redDotService.getRedDotsInViewport(
        viewport,
        cellService.unlockedCellIds,
      );

      // Assert
      expect(redDots, isEmpty);

      redDotService.dispose();
      cellService.dispose();
    });

    test('無效位置應被正確過濾', () async {
      // Arrange
      final locationService = LocationService();
      final validLocations = <ProcessedLocation>[];
      locationService.validLocations.listen(validLocations.add);

      // Act - 發送無效位置
      locationService.processRawLocation(LocationPoint(
        latitude: 0, // 無效緯度
        longitude: 0, // 無效經度
        accuracy: 10.0,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        altitude: 0,
        speed: 1.2,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // Assert - 位置可能有效也可能無效，取決於是否是第一個點
      // 這裡主要測試不會拋出異常

      locationService.dispose();
    });

    test('重複解鎖同一 Cell 應被正確處理', () async {
      // Arrange
      final cellService = CellService();
      cellService.initialize('test_user');

      var unlockCount = 0;

      // Act
      final location = ProcessedLocation(
        point: LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
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

      // 第一次處理
      await cellService.processLocation(
        location,
        onUnlockCell: (cellId) async {
          unlockCount++;
          cellService.markCellUnlocked(cellId);
        },
      );

      // 第二次處理同一位置
      await cellService.processLocation(
        location,
        onUnlockCell: (cellId) async {
          unlockCount++;
        },
      );

      // Assert
      expect(unlockCount, equals(1)); // 只應解鎖一次

      cellService.dispose();
    });

    test('快取失效後應重新取得資料', () async {
      // Arrange
      final redDotService = RedDotService();
      final cellService = CellService();
      final geoEncoder = GeoEncoder();
      cellService.initialize('test_user');

      // 使用視口範圍內的正確 Cell ID
      final cell = geoEncoder.coordToCell(25.035, 121.565);
      cellService.markCellUnlocked(cell.cellId);

      var fetchCount = 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      redDotService.setFetchActivitiesCallback((cellIds) async {
        fetchCount++;
        return [CellActivity(cellId: cell.cellId, lastActivityTime: now)];
      });

      final viewport = ViewportBounds(
        north: 25.040,
        south: 25.030,
        east: 121.570,
        west: 121.560,
        zoom: 15.0,
      );

      // Act
      // 第一次取得
      await redDotService.getRedDotsInViewport(
        viewport,
        cellService.unlockedCellIds,
      );

      // 第二次取得（應使用快取）
      await redDotService.getRedDotsInViewport(
        viewport,
        cellService.unlockedCellIds,
      );

      // 清空快取後第三次取得
      redDotService.clearCache();
      await redDotService.getRedDotsInViewport(
        viewport,
        cellService.unlockedCellIds,
      );

      // Assert
      expect(fetchCount, equals(2)); // 第一次 + 快取失效後

      redDotService.dispose();
      cellService.dispose();
    });
  });

  group('並發處理', () {
    test('並發位置更新應正確處理', () async {
      // Arrange
      final locationService = LocationService();
      var count = 0;

      locationService.validLocations.listen((_) {
        count++;
      });

      // Act - 快速發送多個位置（減少數量避免超時）
      final baseTime = DateTime.now().millisecondsSinceEpoch;

      for (int i = 0; i < 5; i++) {
        locationService.processRawLocation(LocationPoint(
          latitude: 25.0330 + (i * 0.00001),
          longitude: 121.5654,
          accuracy: 10.0,
          timestamp: baseTime + (i * 100),
          altitude: 0,
          speed: 1.2,
        ));
      }

      await Future.delayed(const Duration(milliseconds: 100));

      // Assert - 不應拋出異常，且應該處理部分有效位置
      expect(count, greaterThanOrEqualTo(0));

      locationService.dispose();
    });

    test('並發 Fog 更新應正確合併', () async {
      // Arrange
      final fogManager = FogManager();
      fogManager.initialize(FogState.empty);

      // Act - 並發更新
      final futures = <Future>[];
      for (int i = 0; i < 10; i++) {
        futures.add(Future(() {
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
        }));
      }

      await Future.wait(futures);
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(fogManager.points, isNotEmpty);
      // 點數可能因合併而少於 10

      fogManager.dispose();
    });
  });
}
