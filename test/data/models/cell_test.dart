import 'package:flutter_test/flutter_test.dart';
import 'package:afterstep_fog/data/models/cell.dart';

void main() {
  group('CellBounds', () {
    test('creates with required properties', () {
      const bounds = CellBounds(
        north: 25.034,
        south: 25.032,
        east: 121.567,
        west: 121.564,
      );

      expect(bounds.north, equals(25.034));
      expect(bounds.south, equals(25.032));
      expect(bounds.east, equals(121.567));
      expect(bounds.west, equals(121.564));
    });

    test('equality works correctly', () {
      const bounds1 = CellBounds(
        north: 25.034,
        south: 25.032,
        east: 121.567,
        west: 121.564,
      );
      const bounds2 = CellBounds(
        north: 25.034,
        south: 25.032,
        east: 121.567,
        west: 121.564,
      );
      const bounds3 = CellBounds(
        north: 25.035,
        south: 25.032,
        east: 121.567,
        west: 121.564,
      );

      expect(bounds1, equals(bounds2));
      expect(bounds1, isNot(equals(bounds3)));
    });
  });

  group('Cell', () {
    test('creates with required properties', () {
      const bounds = CellBounds(
        north: 25.034,
        south: 25.032,
        east: 121.567,
        west: 121.564,
      );
      const cell = Cell(
        cellId: '100:200',
        latIndex: 100,
        lngIndex: 200,
        centerLat: 25.033,
        centerLng: 121.5655,
        bounds: bounds,
      );

      expect(cell.cellId, equals('100:200'));
      expect(cell.latIndex, equals(100));
      expect(cell.lngIndex, equals(200));
      expect(cell.centerLat, equals(25.033));
      expect(cell.centerLng, equals(121.5655));
    });

    test('serializes to map', () {
      const bounds = CellBounds(
        north: 25.034,
        south: 25.032,
        east: 121.567,
        west: 121.564,
      );
      const cell = Cell(
        cellId: '100:200',
        latIndex: 100,
        lngIndex: 200,
        centerLat: 25.033,
        centerLng: 121.5655,
        bounds: bounds,
      );

      final map = cell.toMap();

      expect(map['cell_id'], equals('100:200'));
      expect(map['lat_index'], equals(100));
      expect(map['lng_index'], equals(200));
      expect(map['center_lat'], equals(25.033));
      expect(map['center_lng'], equals(121.5655));
      expect(map['bounds_north'], equals(25.034));
      expect(map['bounds_south'], equals(25.032));
    });

    test('deserializes from map', () {
      final map = {
        'cell_id': '100:200',
        'lat_index': 100,
        'lng_index': 200,
        'center_lat': 25.033,
        'center_lng': 121.5655,
        'bounds_north': 25.034,
        'bounds_south': 25.032,
        'bounds_east': 121.567,
        'bounds_west': 121.564,
      };

      final cell = Cell.fromMap(map);

      expect(cell.cellId, equals('100:200'));
      expect(cell.latIndex, equals(100));
      expect(cell.lngIndex, equals(200));
      expect(cell.bounds.north, equals(25.034));
    });

    test('equality works correctly', () {
      const bounds = CellBounds(
        north: 25.034,
        south: 25.032,
        east: 121.567,
        west: 121.564,
      );
      const cell1 = Cell(
        cellId: '100:200',
        latIndex: 100,
        lngIndex: 200,
        centerLat: 25.033,
        centerLng: 121.5655,
        bounds: bounds,
      );
      const cell2 = Cell(
        cellId: '100:200',
        latIndex: 100,
        lngIndex: 200,
        centerLat: 25.033,
        centerLng: 121.5655,
        bounds: bounds,
      );

      expect(cell1, equals(cell2));
    });
  });

  group('UserCellState', () {
    test('creates with required properties', () {
      const state = UserCellState(
        cellId: 'cell_1',
        unlocked: true,
        unlockedAt: 1000000,
      );

      expect(state.cellId, equals('cell_1'));
      expect(state.unlocked, isTrue);
      expect(state.unlockedAt, equals(1000000));
    });

    test('creates with optional properties', () {
      const state = UserCellState(
        cellId: 'cell_1',
        unlocked: true,
        unlockedAt: 1000000,
        lastVisit: 2000000,
        microEventCooldown: 3000000,
      );

      expect(state.lastVisit, equals(2000000));
      expect(state.microEventCooldown, equals(3000000));
    });

    test('serializes to map', () {
      const state = UserCellState(
        cellId: 'cell_1',
        unlocked: true,
        unlockedAt: 1000000,
      );

      final map = state.toMap();

      expect(map['cell_id'], equals('cell_1'));
      expect(map['unlocked'], isTrue);
      expect(map['unlocked_at'], equals(1000000));
    });

    test('deserializes from map', () {
      final map = {
        'cell_id': 'cell_1',
        'unlocked': true,
        'unlocked_at': 1000000,
      };

      final state = UserCellState.fromMap(map);

      expect(state.cellId, equals('cell_1'));
      expect(state.unlocked, isTrue);
    });

    test('copyWith creates modified copy', () {
      const original = UserCellState(
        cellId: 'cell_1',
        unlocked: false,
      );

      final modified = original.copyWith(unlocked: true, unlockedAt: 1000000);

      expect(modified.cellId, equals('cell_1'));
      expect(modified.unlocked, isTrue);
      expect(modified.unlockedAt, equals(1000000));
    });
  });

  group('CellActivity', () {
    test('creates with required properties', () {
      const activity = CellActivity(
        cellId: 'cell_1',
        lastActivityTime: 1000000,
      );

      expect(activity.cellId, equals('cell_1'));
      expect(activity.lastActivityTime, equals(1000000));
    });

    test('serializes to map', () {
      const activity = CellActivity(
        cellId: 'cell_1',
        lastActivityTime: 1000000,
      );

      final map = activity.toMap();

      expect(map['cell_id'], equals('cell_1'));
      expect(map['last_activity_time'], equals(1000000));
    });

    test('deserializes from map', () {
      final map = {
        'cell_id': 'cell_1',
        'last_activity_time': 1000000,
      };

      final activity = CellActivity.fromMap(map);

      expect(activity.cellId, equals('cell_1'));
      expect(activity.lastActivityTime, equals(1000000));
    });

    test('equality works correctly', () {
      const activity1 = CellActivity(
        cellId: 'cell_1',
        lastActivityTime: 1000000,
      );
      const activity2 = CellActivity(
        cellId: 'cell_1',
        lastActivityTime: 1000000,
      );

      expect(activity1, equals(activity2));
    });
  });
}
