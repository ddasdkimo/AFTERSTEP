import 'package:flutter_test/flutter_test.dart';
import 'package:afterstep_fog/data/models/unlock_point.dart';

void main() {
  group('UnlockType', () {
    test('has expected values', () {
      expect(UnlockType.values.length, equals(2));
      expect(UnlockType.walk, isNotNull);
      expect(UnlockType.stay, isNotNull);
    });
  });

  group('UnlockPoint', () {
    test('creates with required properties', () {
      const point = UnlockPoint(
        id: 'point_1',
        latitude: 25.0330,
        longitude: 121.5654,
        radius: 50.0,
        timestamp: 1000000,
        type: UnlockType.walk,
      );

      expect(point.id, equals('point_1'));
      expect(point.latitude, equals(25.0330));
      expect(point.longitude, equals(121.5654));
      expect(point.radius, equals(50.0));
      expect(point.timestamp, equals(1000000));
      expect(point.type, equals(UnlockType.walk));
      expect(point.synced, isFalse);
    });

    test('creates with synced property', () {
      const point = UnlockPoint(
        id: 'point_1',
        latitude: 25.0330,
        longitude: 121.5654,
        radius: 50.0,
        timestamp: 1000000,
        type: UnlockType.stay,
        synced: true,
      );

      expect(point.type, equals(UnlockType.stay));
      expect(point.synced, isTrue);
    });

    test('serializes to map', () {
      const point = UnlockPoint(
        id: 'point_1',
        latitude: 25.0330,
        longitude: 121.5654,
        radius: 50.0,
        timestamp: 1000000,
        type: UnlockType.walk,
        synced: true,
      );

      final map = point.toMap();

      expect(map['id'], equals('point_1'));
      expect(map['latitude'], equals(25.0330));
      expect(map['longitude'], equals(121.5654));
      expect(map['radius'], equals(50.0));
      expect(map['timestamp'], equals(1000000));
      expect(map['type'], equals('walk'));
      expect(map['synced'], equals(1));
    });

    test('deserializes from map', () {
      final map = {
        'id': 'point_1',
        'latitude': 25.0330,
        'longitude': 121.5654,
        'radius': 50.0,
        'timestamp': 1000000,
        'type': 'stay',
        'synced': true,
      };

      final point = UnlockPoint.fromMap(map);

      expect(point.id, equals('point_1'));
      expect(point.latitude, equals(25.0330));
      expect(point.longitude, equals(121.5654));
      expect(point.radius, equals(50.0));
      expect(point.timestamp, equals(1000000));
      expect(point.type, equals(UnlockType.stay));
      expect(point.synced, isTrue);
    });

    test('deserializes with default type', () {
      final map = {
        'id': 'point_1',
        'latitude': 25.0330,
        'longitude': 121.5654,
        'radius': 50.0,
        'timestamp': 1000000,
        'type': 'unknown',
      };

      final point = UnlockPoint.fromMap(map);
      expect(point.type, equals(UnlockType.walk));
    });

    test('copyWith creates modified copy', () {
      const original = UnlockPoint(
        id: 'point_1',
        latitude: 25.0330,
        longitude: 121.5654,
        radius: 50.0,
        timestamp: 1000000,
        type: UnlockType.walk,
      );

      final modified = original.copyWith(
        radius: 75.0,
        latitude: 25.0340,
        synced: true,
      );

      expect(modified.id, equals('point_1'));
      expect(modified.latitude, equals(25.0340));
      expect(modified.longitude, equals(121.5654));
      expect(modified.radius, equals(75.0));
      expect(modified.synced, isTrue);
    });

    test('equality works correctly', () {
      const point1 = UnlockPoint(
        id: 'point_1',
        latitude: 25.0330,
        longitude: 121.5654,
        radius: 50.0,
        timestamp: 1000000,
        type: UnlockType.walk,
      );
      const point2 = UnlockPoint(
        id: 'point_1',
        latitude: 25.0330,
        longitude: 121.5654,
        radius: 50.0,
        timestamp: 1000000,
        type: UnlockType.walk,
      );
      const point3 = UnlockPoint(
        id: 'point_2',
        latitude: 25.0330,
        longitude: 121.5654,
        radius: 50.0,
        timestamp: 1000000,
        type: UnlockType.walk,
      );

      expect(point1, equals(point2));
      expect(point1, isNot(equals(point3)));
    });
  });

  group('UnlockPath', () {
    test('creates with required properties', () {
      const path = UnlockPath(
        id: 'path_1',
        points: [(lat: 25.0330, lng: 121.5654), (lat: 25.0331, lng: 121.5655)],
        width: 20.0,
        timestamp: 1000000,
      );

      expect(path.id, equals('path_1'));
      expect(path.points.length, equals(2));
      expect(path.width, equals(20.0));
      expect(path.timestamp, equals(1000000));
      expect(path.synced, isFalse);
    });

    test('serializes to map', () {
      const path = UnlockPath(
        id: 'path_1',
        points: [(lat: 25.0330, lng: 121.5654), (lat: 25.0331, lng: 121.5655)],
        width: 20.0,
        timestamp: 1000000,
      );

      final map = path.toMap();

      expect(map['id'], equals('path_1'));
      expect(map['points'], isA<String>());
      expect(map['width'], equals(20.0));
      expect(map['timestamp'], equals(1000000));
    });

    test('deserializes from map', () {
      final map = {
        'id': 'path_1',
        'points': '25033000,121565400;100,100',
        'width': 20.0,
        'timestamp': 1000000,
      };

      final path = UnlockPath.fromMap(map);

      expect(path.id, equals('path_1'));
      expect(path.points.length, equals(2));
      expect(path.width, equals(20.0));
    });

    test('copyWith creates modified copy', () {
      const original = UnlockPath(
        id: 'path_1',
        points: [(lat: 25.0330, lng: 121.5654)],
        width: 20.0,
        timestamp: 1000000,
      );

      final modified = original.copyWith(
        width: 30.0,
        synced: true,
      );

      expect(modified.id, equals('path_1'));
      expect(modified.width, equals(30.0));
      expect(modified.synced, isTrue);
    });
  });

  group('FogState', () {
    test('creates empty state', () {
      const state = FogState.empty;

      expect(state.points, isEmpty);
      expect(state.paths, isEmpty);
      expect(state.totalUnlockedArea, equals(0.0));
      expect(state.lastSyncTime, equals(0));
    });

    test('creates with properties', () {
      const points = [
        UnlockPoint(
          id: 'point_1',
          latitude: 25.0330,
          longitude: 121.5654,
          radius: 50.0,
          timestamp: 1000000,
          type: UnlockType.walk,
        ),
      ];
      const paths = <UnlockPath>[];
      const state = FogState(
        points: points,
        paths: paths,
        totalUnlockedArea: 1000.0,
        lastSyncTime: 2000000,
      );

      expect(state.points.length, equals(1));
      expect(state.paths, isEmpty);
      expect(state.totalUnlockedArea, equals(1000.0));
      expect(state.lastSyncTime, equals(2000000));
    });

    test('copyWith creates modified copy', () {
      const original = FogState.empty;
      const newPoints = [
        UnlockPoint(
          id: 'point_1',
          latitude: 25.0330,
          longitude: 121.5654,
          radius: 50.0,
          timestamp: 1000000,
          type: UnlockType.walk,
        ),
      ];

      final modified = original.copyWith(
        points: newPoints,
        totalUnlockedArea: 500.0,
      );

      expect(modified.points.length, equals(1));
      expect(modified.totalUnlockedArea, equals(500.0));
      expect(modified.lastSyncTime, equals(0));
    });

    test('equality works correctly', () {
      const state1 = FogState.empty;
      const state2 = FogState.empty;

      expect(state1, equals(state2));
    });
  });
}
