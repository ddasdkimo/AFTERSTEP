import 'package:flutter_test/flutter_test.dart';
import 'package:afterstep_fog/features/location/drift_filter.dart';
import 'package:afterstep_fog/data/models/location_point.dart';

void main() {
  group('DriftFilter', () {
    late DriftFilter filter;

    setUp(() {
      filter = DriftFilter();
    });

    group('process', () {
      test('returns true for non-stationary state', () {
        final point = LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 1000000,
        );

        final result = filter.process(point, MovementState.walking);
        expect(result, isTrue);
      });

      test('accepts first stationary point', () {
        final point = LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 1000000,
        );

        final result = filter.process(point, MovementState.stationary);
        expect(result, isTrue);
        expect(filter.isStationary, isTrue);
      });

      test('accepts nearby stationary points', () {
        final point1 = LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 1000000,
        );
        final point2 = LocationPoint(
          latitude: 25.03301,
          longitude: 121.56541,
          accuracy: 10,
          timestamp: 1005000,
        );

        filter.process(point1, MovementState.stationary);
        final result = filter.process(point2, MovementState.stationary);

        expect(result, isTrue);
      });

      test('rejects drift within time window', () {
        final point1 = LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 1000000,
        );
        // Point 2 is far away but within drift time window
        final point2 = LocationPoint(
          latitude: 25.0340, // ~100m away
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 1003000, // 3 seconds later
        );

        filter.process(point1, MovementState.stationary);
        final result = filter.process(point2, MovementState.stationary);

        expect(result, isFalse);
      });

      test('accepts movement after long time', () {
        final point1 = LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 1000000,
        );
        // Point 2 is far away but after drift time window
        final point2 = LocationPoint(
          latitude: 25.0340, // ~100m away
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 1030000, // 30 seconds later
        );

        filter.process(point1, MovementState.stationary);
        final result = filter.process(point2, MovementState.stationary);

        expect(result, isTrue);
      });

      test('resets stationary center when moving', () {
        final point1 = LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 1000000,
        );
        final point2 = LocationPoint(
          latitude: 25.0331,
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 1005000,
        );

        filter.process(point1, MovementState.stationary);
        expect(filter.isStationary, isTrue);

        filter.process(point2, MovementState.walking);
        expect(filter.isStationary, isFalse);
      });
    });

    group('stationaryCenter', () {
      test('returns null when not stationary', () {
        expect(filter.stationaryCenter, isNull);
      });

      test('returns center point when stationary', () {
        final point = LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 1000000,
        );

        filter.process(point, MovementState.stationary);

        expect(filter.stationaryCenter, isNotNull);
        expect(filter.stationaryCenter!.latitude, equals(25.0330));
      });
    });

    group('stationaryStartTime', () {
      test('returns 0 initially', () {
        expect(filter.stationaryStartTime, equals(0));
      });

      test('returns start time when stationary', () {
        final point = LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 1000000,
        );

        filter.process(point, MovementState.stationary);

        expect(filter.stationaryStartTime, equals(1000000));
      });
    });

    group('reset', () {
      test('clears all state', () {
        final point = LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 1000000,
        );

        filter.process(point, MovementState.stationary);
        expect(filter.isStationary, isTrue);

        filter.reset();

        expect(filter.isStationary, isFalse);
        expect(filter.stationaryCenter, isNull);
        expect(filter.stationaryStartTime, equals(0));
      });
    });
  });
}
