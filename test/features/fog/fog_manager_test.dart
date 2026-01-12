import 'package:flutter_test/flutter_test.dart';
import 'package:afterstep_fog/features/fog/fog_manager.dart';
import 'package:afterstep_fog/data/models/location_point.dart';
import 'package:afterstep_fog/data/models/unlock_point.dart';
import 'package:afterstep_fog/core/config/constants.dart';

void main() {
  group('FogManager', () {
    late FogManager manager;

    setUp(() {
      manager = FogManager();
    });

    tearDown(() {
      manager.dispose();
    });

    group('initialize', () {
      test('initializes with empty state', () {
        expect(manager.state, equals(FogState.empty));
        expect(manager.points, isEmpty);
        expect(manager.paths, isEmpty);
      });

      test('initializes with provided state', () {
        final initialState = FogState(
          points: [
            UnlockPoint(
              id: 'test_1',
              latitude: 25.0330,
              longitude: 121.5654,
              radius: 15,
              timestamp: 1000,
              type: UnlockType.walk,
            ),
          ],
          paths: [],
          totalUnlockedArea: 0,
          lastSyncTime: 0,
        );

        manager.initialize(initialState);

        expect(manager.points.length, equals(1));
        expect(manager.points.first.id, equals('test_1'));
      });
    });

    group('processValidLocation', () {
      test('adds unlock point for new location', () {
        final location = ProcessedLocation(
          point: LocationPoint(
            latitude: 25.0330,
            longitude: 121.5654,
            accuracy: 10,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
          calculatedSpeed: 1.2,
          movementState: MovementState.walking,
          isValid: true,
          distanceFromLast: 10,
        );

        manager.processValidLocation(location);

        expect(manager.points.length, equals(1));
        expect(manager.points.first.latitude, closeTo(25.0330, 0.0001));
        expect(manager.points.first.longitude, closeTo(121.5654, 0.0001));
      });

      test('merges nearby points', () {
        // Add first point
        final location1 = ProcessedLocation(
          point: LocationPoint(
            latitude: 25.0330,
            longitude: 121.5654,
            accuracy: 10,
            timestamp: 0,
          ),
          calculatedSpeed: 1.2,
          movementState: MovementState.walking,
          isValid: true,
          distanceFromLast: 10,
        );

        manager.processValidLocation(location1);

        // Add very close point (within merge distance)
        final location2 = ProcessedLocation(
          point: LocationPoint(
            latitude: 25.0330 + 0.00001, // ~1m away
            longitude: 121.5654,
            accuracy: 10,
            timestamp: 3000,
          ),
          calculatedSpeed: 1.2,
          movementState: MovementState.walking,
          isValid: true,
          distanceFromLast: 1,
        );

        manager.processValidLocation(location2);

        // Should still have 1 point (merged)
        expect(manager.points.length, equals(1));
      });

      test('creates new point for distant location', () {
        final location1 = ProcessedLocation(
          point: LocationPoint(
            latitude: 25.0330,
            longitude: 121.5654,
            accuracy: 10,
            timestamp: 0,
          ),
          calculatedSpeed: 1.2,
          movementState: MovementState.walking,
          isValid: true,
          distanceFromLast: 0,
        );

        manager.processValidLocation(location1);

        // Add distant point (beyond merge distance)
        final location2 = ProcessedLocation(
          point: LocationPoint(
            latitude: 25.0340, // ~100m away
            longitude: 121.5654,
            accuracy: 10,
            timestamp: 60000,
          ),
          calculatedSpeed: 1.2,
          movementState: MovementState.walking,
          isValid: true,
          distanceFromLast: 100,
        );

        manager.processValidLocation(location2);

        // Should have 2 points
        expect(manager.points.length, equals(2));
      });
    });

    group('processStayEvent', () {
      test('creates stay unlock point', () {
        final stay = StayEvent(
          centerLat: 25.0330,
          centerLng: 121.5654,
          startTime: 0,
          duration: GpsConfig.stayMinDuration + 10,
          radius: 10,
        );

        manager.processStayEvent(stay);

        expect(manager.points.length, equals(1));
        expect(manager.points.first.type, equals(UnlockType.stay));
        expect(manager.points.first.radius, equals(FogConfig.unlockRadiusStay));
      });

      test('ignores short stays', () {
        final stay = StayEvent(
          centerLat: 25.0330,
          centerLng: 121.5654,
          startTime: 0,
          duration: 10, // Too short
          radius: 10,
        );

        manager.processStayEvent(stay);

        expect(manager.points, isEmpty);
      });

      test('expands existing nearby point for stay', () {
        // First add a walk point
        final location = ProcessedLocation(
          point: LocationPoint(
            latitude: 25.0330,
            longitude: 121.5654,
            accuracy: 10,
            timestamp: 0,
          ),
          calculatedSpeed: 1.2,
          movementState: MovementState.walking,
          isValid: true,
          distanceFromLast: 0,
        );

        manager.processValidLocation(location);
        final initialRadius = manager.points.first.radius;

        // Then stay at same location
        final stay = StayEvent(
          centerLat: 25.0330,
          centerLng: 121.5654,
          startTime: 0,
          duration: GpsConfig.stayMinDuration + 10,
          radius: 10,
        );

        manager.processStayEvent(stay);

        // Should still have 1 point but with expanded radius
        expect(manager.points.length, equals(1));
        expect(manager.points.first.radius, greaterThanOrEqualTo(initialRadius));
      });
    });

    group('fogUpdated stream', () {
      test('emits state changes', () async {
        final states = <FogState>[];
        final subscription = manager.fogUpdated.listen(states.add);

        final location = ProcessedLocation(
          point: LocationPoint(
            latitude: 25.0330,
            longitude: 121.5654,
            accuracy: 10,
            timestamp: 0,
          ),
          calculatedSpeed: 1.2,
          movementState: MovementState.walking,
          isValid: true,
          distanceFromLast: 0,
        );

        manager.processValidLocation(location);

        await Future.delayed(Duration(milliseconds: 100));
        await subscription.cancel();

        expect(states, isNotEmpty);
      });
    });

    group('getPointsInViewport', () {
      test('returns points within viewport', () {
        // Add points at different locations
        manager.initialize(FogState(
          points: [
            UnlockPoint(
              id: '1',
              latitude: 25.0330,
              longitude: 121.5654,
              radius: 15,
              timestamp: 0,
              type: UnlockType.walk,
            ),
            UnlockPoint(
              id: '2',
              latitude: 25.0340,
              longitude: 121.5664,
              radius: 15,
              timestamp: 0,
              type: UnlockType.walk,
            ),
            UnlockPoint(
              id: '3',
              latitude: 26.0000, // Outside viewport
              longitude: 122.0000,
              radius: 15,
              timestamp: 0,
              type: UnlockType.walk,
            ),
          ],
          paths: [],
          totalUnlockedArea: 0,
          lastSyncTime: 0,
        ));

        final inViewport = manager.getPointsInViewport(
          25.05, // north
          25.02, // south
          121.58, // east
          121.55, // west
        );

        expect(inViewport.length, equals(2));
      });
    });

    group('reset', () {
      test('clears all state', () {
        final location = ProcessedLocation(
          point: LocationPoint(
            latitude: 25.0330,
            longitude: 121.5654,
            accuracy: 10,
            timestamp: 0,
          ),
          calculatedSpeed: 1.2,
          movementState: MovementState.walking,
          isValid: true,
          distanceFromLast: 0,
        );

        manager.processValidLocation(location);
        expect(manager.points, isNotEmpty);

        manager.reset();

        expect(manager.points, isEmpty);
        expect(manager.paths, isEmpty);
      });
    });
  });
}
