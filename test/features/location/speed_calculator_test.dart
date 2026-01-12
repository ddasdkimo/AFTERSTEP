import 'package:flutter_test/flutter_test.dart';
import 'package:afterstep_fog/features/location/speed_calculator.dart';
import 'package:afterstep_fog/data/models/location_point.dart';
import 'package:afterstep_fog/core/config/constants.dart';

void main() {
  group('SpeedCalculator', () {
    late SpeedCalculator calculator;

    setUp(() {
      calculator = SpeedCalculator(bufferSize: 3);
    });

    group('calculate', () {
      test('returns 0 for same timestamp', () {
        final point1 = LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 1000000,
        );
        final point2 = LocationPoint(
          latitude: 25.0331,
          longitude: 121.5655,
          accuracy: 10,
          timestamp: 1000000, // same timestamp
        );

        final speed = calculator.calculate(point2, point1);
        expect(speed, equals(0));
      });

      test('calculates speed for moving point', () {
        final point1 = LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 0,
        );
        // Move approximately 10 meters north
        final point2 = LocationPoint(
          latitude: 25.03309,
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 10000, // 10 seconds later
        );

        final speed = calculator.calculate(point2, point1);
        expect(speed, greaterThan(0));
        expect(speed, lessThan(5)); // Should be around 1 m/s
      });

      test('smooths speed with buffer', () {
        final baseTime = 1000000;
        final points = <LocationPoint>[];

        // Create 5 points with varying distances
        for (var i = 0; i <= 5; i++) {
          points.add(LocationPoint(
            latitude: 25.0330 + (i * 0.00009),
            longitude: 121.5654,
            accuracy: 10,
            timestamp: baseTime + (i * 10000),
          ));
        }

        final speeds = <double>[];
        for (var i = 1; i < points.length; i++) {
          speeds.add(calculator.calculate(points[i], points[i - 1]));
        }

        // Smoothed speeds should be relatively stable
        for (var i = 1; i < speeds.length; i++) {
          expect((speeds[i] - speeds[i - 1]).abs(), lessThan(2));
        }
      });
    });

    group('lastInstantSpeed', () {
      test('returns 0 when empty', () {
        expect(calculator.lastInstantSpeed, equals(0));
      });

      test('returns last calculated speed', () {
        final point1 = LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 0,
        );
        final point2 = LocationPoint(
          latitude: 25.0331,
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 10000,
        );

        calculator.calculate(point2, point1);
        expect(calculator.lastInstantSpeed, greaterThan(0));
      });
    });

    group('reset', () {
      test('clears buffer', () {
        final point1 = LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 0,
        );
        final point2 = LocationPoint(
          latitude: 25.0331,
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 10000,
        );

        calculator.calculate(point2, point1);
        expect(calculator.lastInstantSpeed, greaterThan(0));

        calculator.reset();
        expect(calculator.lastInstantSpeed, equals(0));
      });
    });
  });

  group('determineMovementState', () {
    test('returns stationary for low speed', () {
      final state = determineMovementState(0.3);
      expect(state, equals(MovementState.stationary));
    });

    test('returns walking for normal walking speed', () {
      final state = determineMovementState(1.2);
      expect(state, equals(MovementState.walking));
    });

    test('returns fastWalking for fast walking speed', () {
      final state = determineMovementState(2.0);
      expect(state, equals(MovementState.fastWalking));
    });

    test('returns tooFast for running/vehicle speed', () {
      final state = determineMovementState(5.0);
      expect(state, equals(MovementState.tooFast));
    });

    test('uses correct thresholds', () {
      // Just below minimum
      expect(
        determineMovementState(GpsConfig.speedMin - 0.1),
        equals(MovementState.stationary),
      );

      // At minimum
      expect(
        determineMovementState(GpsConfig.speedMin),
        equals(MovementState.walking),
      );

      // At maximum
      expect(
        determineMovementState(GpsConfig.speedMax),
        equals(MovementState.walking),
      );

      // Just above maximum
      expect(
        determineMovementState(GpsConfig.speedMax + 0.1),
        equals(MovementState.fastWalking),
      );

      // At cutoff
      expect(
        determineMovementState(GpsConfig.speedCutoff),
        equals(MovementState.fastWalking),
      );

      // Above cutoff
      expect(
        determineMovementState(GpsConfig.speedCutoff + 0.1),
        equals(MovementState.tooFast),
      );
    });
  });

  group('getUnlockEfficiency', () {
    test('returns 0 for stationary', () {
      final efficiency = getUnlockEfficiency(MovementState.stationary, 0.3);
      expect(efficiency, equals(0));
    });

    test('returns 1.0 for walking', () {
      final efficiency = getUnlockEfficiency(MovementState.walking, 1.2);
      expect(efficiency, equals(1.0));
    });

    test('returns decreasing value for fastWalking', () {
      // At start of fast walking (just above speedMax)
      final efficiencyStart = getUnlockEfficiency(
        MovementState.fastWalking,
        GpsConfig.speedMax + 0.1,
      );
      expect(efficiencyStart, greaterThan(0.8));
      expect(efficiencyStart, lessThan(1.0));

      // At end of fast walking (near speedCutoff)
      final efficiencyEnd = getUnlockEfficiency(
        MovementState.fastWalking,
        GpsConfig.speedCutoff - 0.1,
      );
      expect(efficiencyEnd, greaterThan(0));
      expect(efficiencyEnd, lessThan(0.2));
    });

    test('returns 0 for tooFast', () {
      final efficiency = getUnlockEfficiency(MovementState.tooFast, 5.0);
      expect(efficiency, equals(0));
    });
  });
}
