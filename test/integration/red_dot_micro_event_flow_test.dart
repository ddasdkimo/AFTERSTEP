import 'dart:async';
import 'dart:math' as math;

import 'package:afterstep_fog/data/models/cell.dart';
import 'package:afterstep_fog/data/models/location_point.dart';
import 'package:afterstep_fog/data/models/micro_event.dart';
import 'package:afterstep_fog/data/models/red_dot.dart';
import 'package:afterstep_fog/features/cell/cell_service.dart';
import 'package:afterstep_fog/features/cell/geo_encoder.dart';
import 'package:afterstep_fog/features/micro_event/cooldown_manager.dart';
import 'package:afterstep_fog/features/micro_event/micro_event_service.dart';
import 'package:afterstep_fog/features/micro_event/text_selector.dart';
import 'package:afterstep_fog/features/red_dot/intensity_calculator.dart';
import 'package:afterstep_fog/features/red_dot/position_obfuscator.dart';
import 'package:afterstep_fog/features/red_dot/red_dot_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 整合測試：紅點系統與微事件系統
///
/// 測試紅點衰減、微事件觸發、冷卻機制的整合行為
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('紅點系統整合', () {
    late RedDotService redDotService;
    late CellService cellService;
    late GeoEncoder geoEncoder;

    setUp(() {
      redDotService = RedDotService();
      cellService = CellService();
      geoEncoder = GeoEncoder();
    });

    tearDown(() {
      redDotService.dispose();
      cellService.dispose();
    });

    test('紅點服務應根據 Cell 活動資料產生紅點', () async {
      // Arrange
      cellService.initialize('test_user');

      // 使用 GeoEncoder 計算正確的 Cell ID
      final cell1 = geoEncoder.coordToCell(25.035, 121.565);
      final cell2 = geoEncoder.coordToCell(25.033, 121.565);
      final cell3 = geoEncoder.coordToCell(25.031, 121.565);

      // 設定活動取得回調
      final now = DateTime.now().millisecondsSinceEpoch;
      final activities = <CellActivity>[
        CellActivity(cellId: cell1.cellId, lastActivityTime: now - 86400000), // 1天前
        CellActivity(cellId: cell2.cellId, lastActivityTime: now - 172800000), // 2天前
        CellActivity(cellId: cell3.cellId, lastActivityTime: now - 432000000), // 5天前 (τ)
      ];

      redDotService.setFetchActivitiesCallback((cellIds) async {
        return activities.where((a) => cellIds.contains(a.cellId)).toList();
      });

      // 標記這些 Cell 為已解鎖
      for (final activity in activities) {
        cellService.markCellUnlocked(activity.cellId);
      }

      // Act - 使用包含這些 Cell 的視口
      final viewport = ViewportBounds(
        north: 25.040,
        south: 25.030,
        east: 121.570,
        west: 121.560,
        zoom: 15.0,
      );

      final redDots = await redDotService.getRedDotsInViewport(
        viewport,
        cellService.unlockedCellIds,
      );

      // Assert
      expect(redDots, isNotEmpty);
      // 應該根據時間有不同的強度
      for (final dot in redDots) {
        expect(dot.intensity, greaterThan(0.0));
        expect(dot.intensity, lessThanOrEqualTo(1.0));
      }
    });

    test('紅點強度應隨時間衰減', () async {
      // Arrange
      final intensityCalc = IntensityCalculator();
      final now = DateTime.now().millisecondsSinceEpoch;

      // Act
      final intensity1Day = intensityCalc.calculate(now - 86400000); // 1天前
      final intensity3Day = intensityCalc.calculate(now - 259200000); // 3天前
      final intensity5Day = intensityCalc.calculate(now - 432000000); // 5天前 (τ)
      final intensity10Day = intensityCalc.calculate(now - 864000000); // 10天前

      // Assert
      expect(intensity1Day, greaterThan(intensity3Day));
      expect(intensity3Day, greaterThan(intensity5Day));
      expect(intensity5Day, greaterThan(intensity10Day));

      // τ=5天時，強度應接近 1/e ≈ 0.368
      expect(intensity5Day, closeTo(0.368, 0.1));
    });

    test('紅點位置應被模糊化', () {
      // Arrange
      final obfuscator = PositionObfuscator();
      final cell = Cell(
        cellId: '100:200',
        latIndex: 100,
        lngIndex: 200,
        centerLat: 25.0330,
        centerLng: 121.5654,
        bounds: const CellBounds(
          north: 25.034,
          south: 25.032,
          east: 121.567,
          west: 121.564,
        ),
      );

      // Act
      final offset1 = obfuscator.applyOffset(cell);
      final offset2 = obfuscator.applyOffset(cell);

      // Assert
      // 同一個 Cell 應該產生相同的偏移
      expect(offset1.lat, equals(offset2.lat));
      expect(offset1.lng, equals(offset2.lng));

      // 偏移應在合理範圍內（50-100米）
      final distanceLat = (offset1.lat - cell.centerLat).abs() * 111000;
      final distanceLng =
          (offset1.lng - cell.centerLng).abs() * 111000 * math.cos(cell.centerLat * math.pi / 180);
      final distance = math.sqrt(distanceLat * distanceLat + distanceLng * distanceLng);

      expect(distance, greaterThanOrEqualTo(50));
      expect(distance, lessThanOrEqualTo(100));
    });

    test('紅點串流應正確發出更新', () async {
      // Arrange
      cellService.initialize('test_user');
      final geoEncoder = GeoEncoder();
      final cell = geoEncoder.coordToCell(25.035, 121.565);
      cellService.markCellUnlocked(cell.cellId);

      final now = DateTime.now().millisecondsSinceEpoch;
      redDotService.setFetchActivitiesCallback((cellIds) async {
        if (cellIds.contains(cell.cellId)) {
          return [CellActivity(cellId: cell.cellId, lastActivityTime: now)];
        }
        return [];
      });

      final updates = <List<RedDot>>[];
      redDotService.redDotsUpdated.listen(updates.add);

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

      await Future.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(updates, isNotEmpty);
    });
  });

  group('微事件系統整合（使用 Mock）', () {
    setUp(() async {
      // 設定 mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
    });

    test('微事件應在停留足夠時間後觸發', () async {
      // Arrange
      final controllableRandom = _AlwaysTriggerRandom();
      final microEventService = MicroEventService(
        random: controllableRandom,
        cooldownManager: CooldownManager(),
        textSelector: TextSelector(),
      );
      await microEventService.initialize();

      final triggeredEvents = <DisplayEvent>[];
      microEventService.eventTriggered.listen(triggeredEvents.add);

      // 設定紅點查詢回調（需要有紅點）
      microEventService.setGetRedDotCallback((cellId) {
        return RedDot(
          id: cellId,
          cellId: cellId,
          originalLat: 25.0330,
          originalLng: 121.5654,
          displayLat: 25.0331,
          displayLng: 121.5655,
          intensity: 0.8,
          size: 10.0,
          opacity: 0.8,
          pulsePhase: 0.5,
        );
      });

      // Act - 使用手動觸發
      microEventService.manualTrigger('test_cell', redDotIntensity: 0.8);

      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(triggeredEvents, isNotEmpty);
      expect(triggeredEvents.first.text, isNotEmpty);

      microEventService.dispose();
    });

    test('冷卻機制應正確限制觸發', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      final microEventService = MicroEventService(
        random: _AlwaysTriggerRandom(),
        cooldownManager: CooldownManager(),
        textSelector: TextSelector(),
      );
      await microEventService.initialize();

      final triggeredEvents = <DisplayEvent>[];
      microEventService.eventTriggered.listen(triggeredEvents.add);

      // Act - 連續觸發同一個 Cell
      microEventService.manualTrigger('test_cell');
      await Future.delayed(const Duration(milliseconds: 50));

      final countAfterFirst = triggeredEvents.length;

      microEventService.manualTrigger('test_cell'); // 應被冷卻阻擋
      await Future.delayed(const Duration(milliseconds: 50));

      // Assert - 第二次應被冷卻阻擋
      expect(triggeredEvents.length, equals(countAfterFirst));

      microEventService.dispose();
    });

    test('每日上限應正確限制觸發', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      final microEventService = MicroEventService(
        random: _AlwaysTriggerRandom(),
        cooldownManager: CooldownManager(),
        textSelector: TextSelector(),
      );
      await microEventService.initialize();
      await microEventService.reset();

      // Act
      final remaining = microEventService.getRemainingToday();

      // Assert
      expect(remaining, equals(3)); // 預設每日上限 3 次

      microEventService.dispose();
    });

    test('不同 Cell 應各自有獨立冷卻', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      final cooldownManager = CooldownManager();
      await cooldownManager.initialize();
      await cooldownManager.reset();

      // Act
      cooldownManager.recordTrigger('cell_1');
      cooldownManager.recordTrigger('cell_2');

      // Assert
      final canTrigger1 = cooldownManager.canTrigger('cell_1');
      final canTrigger2 = cooldownManager.canTrigger('cell_2');
      final canTrigger3 = cooldownManager.canTrigger('cell_3');

      expect(canTrigger1.allowed, isFalse); // 已觸發，進入冷卻
      expect(canTrigger2.allowed, isFalse); // 已觸發，進入冷卻
      // cell_3 尚未觸發且每日上限未達，應該可以觸發
      expect(canTrigger3.allowed, isTrue);
    });
  });

  group('紅點與微事件聯動', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('有紅點的 Cell 應能觸發微事件', () async {
      // Arrange
      final redDotService = RedDotService();
      final cellService = CellService();
      final geoEncoder = GeoEncoder();

      // 計算位於視口內的 Cell
      final cell = geoEncoder.coordToCell(25.035, 121.565);
      final now = DateTime.now().millisecondsSinceEpoch;

      cellService.initialize('test_user');
      cellService.markCellUnlocked(cell.cellId);

      redDotService.setFetchActivitiesCallback((cellIds) async {
        if (cellIds.contains(cell.cellId)) {
          return [CellActivity(cellId: cell.cellId, lastActivityTime: now)];
        }
        return [];
      });

      // 先取得紅點
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

      // 設定微事件
      final microEventService = MicroEventService(
        random: _AlwaysTriggerRandom(),
      );
      await microEventService.initialize();
      microEventService.setGetRedDotCallback(redDotService.getRedDotForCell);

      // Act
      final triggeredEvents = <DisplayEvent>[];
      microEventService.eventTriggered.listen(triggeredEvents.add);

      microEventService.manualTrigger(cell.cellId);

      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(triggeredEvents, isNotEmpty);

      // 清理
      redDotService.dispose();
      microEventService.dispose();
      cellService.dispose();
    });

    test('Cell 解鎖後應能在該區域看到紅點', () async {
      // Arrange
      final redDotService = RedDotService();
      final cellService = CellService();
      final geoEncoder = GeoEncoder();

      // 計算視口內的 Cell
      final cell = geoEncoder.coordToCell(25.035, 121.565);
      final now = DateTime.now().millisecondsSinceEpoch;

      cellService.initialize('test_user');

      redDotService.setFetchActivitiesCallback((cellIds) async {
        if (cellIds.contains(cell.cellId)) {
          return [CellActivity(cellId: cell.cellId, lastActivityTime: now)];
        }
        return [];
      });

      // 先不解鎖 - 不應該有紅點
      final viewport = ViewportBounds(
        north: 25.040,
        south: 25.030,
        east: 121.570,
        west: 121.560,
        zoom: 15.0,
      );

      var redDots = await redDotService.getRedDotsInViewport(
        viewport,
        cellService.unlockedCellIds,
      );

      expect(redDots, isEmpty);

      // Act - 解鎖 Cell
      cellService.markCellUnlocked(cell.cellId);
      redDotService.clearCache();

      redDots = await redDotService.getRedDotsInViewport(
        viewport,
        cellService.unlockedCellIds,
      );

      // Assert
      expect(redDots, isNotEmpty);
      expect(redDots.first.cellId, equals(cell.cellId));

      // 清理
      redDotService.dispose();
      cellService.dispose();
    });
  });

  group('完整使用者旅程測試', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('從步行到看見紅點到觸發微事件的完整流程', () async {
      // 這個測試模擬完整的使用者旅程
      final geoEncoder = GeoEncoder();

      // 1. 使用者開始步行
      final cellService = CellService();
      cellService.initialize('test_user');

      // 2. 步行解鎖 Cell
      final location = ProcessedLocation(
        point: LocationPoint(
          latitude: 25.0350,
          longitude: 121.5650,
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

      final unlockedCells = <String>[];
      await cellService.processLocation(
        location,
        onUnlockCell: (cellId) async {
          unlockedCells.add(cellId);
          cellService.markCellUnlocked(cellId);
        },
      );

      expect(unlockedCells, isNotEmpty);

      // 3. 查看紅點
      final redDotService = RedDotService();
      final now = DateTime.now().millisecondsSinceEpoch;

      redDotService.setFetchActivitiesCallback((cellIds) async {
        return cellIds.map((id) {
          return CellActivity(cellId: id, lastActivityTime: now - 86400000);
        }).toList();
      });

      final viewport = ViewportBounds(
        north: 25.040,
        south: 25.030,
        east: 121.570,
        west: 121.560,
        zoom: 15.0,
      );

      final redDots = await redDotService.getRedDotsInViewport(
        viewport,
        cellService.unlockedCellIds,
      );

      expect(redDots, isNotEmpty);

      // 4. 停留觸發微事件
      final microEventService = MicroEventService(
        random: _AlwaysTriggerRandom(),
      );
      await microEventService.initialize();

      microEventService.setGetRedDotCallback((cellId) {
        return redDots.where((d) => d.cellId == cellId).firstOrNull;
      });

      final triggeredEvents = <DisplayEvent>[];
      microEventService.eventTriggered.listen(triggeredEvents.add);

      microEventService.manualTrigger(unlockedCells.first);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(triggeredEvents, isNotEmpty);
      expect(triggeredEvents.first.text, isNotEmpty);

      // 清理
      cellService.dispose();
      redDotService.dispose();
      microEventService.dispose();
    });
  });
}

/// 總是觸發的隨機數產生器（用於測試）
class _AlwaysTriggerRandom implements math.Random {
  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0.1; // 總是小於 0.25 觸發機率

  @override
  int nextInt(int max) => 0;
}
