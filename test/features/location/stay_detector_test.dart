import 'package:flutter_test/flutter_test.dart';
import 'package:afterstep_fog/features/location/stay_detector.dart';
import 'package:afterstep_fog/data/models/location_point.dart';

void main() {
  group('StayDetector', () {
    late StayDetector detector;

    setUp(() {
      detector = StayDetector();
    });

    group('process', () {
      test('returns null for single point', () {
        final point = LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 1000000,
        );

        final result = detector.process(point);
        expect(result, isNull);
      });

      test('creates stay event after minimum duration', () {
        final baseTime = 1000000;

        // Add points for 60+ seconds (minimum stay duration)
        for (var i = 0; i <= 60; i += 5) {
          final point = LocationPoint(
            latitude: 25.0330 + (i * 0.000001), // tiny movement
            longitude: 121.5654,
            accuracy: 10,
            timestamp: baseTime + (i * 1000),
          );
          detector.process(point);
        }

        expect(detector.isStaying, isTrue);
        expect(detector.currentStay, isNotNull);
        expect(detector.currentStay!.duration, greaterThanOrEqualTo(45));
      });

      test('returns completed stay when user leaves', () {
        final baseTime = 1000000;

        // First, stay for 60 seconds
        for (var i = 0; i <= 60; i += 5) {
          final point = LocationPoint(
            latitude: 25.0330,
            longitude: 121.5654,
            accuracy: 10,
            timestamp: baseTime + (i * 1000),
          );
          detector.process(point);
        }

        expect(detector.isStaying, isTrue);

        // Then move away
        final leavePoint = LocationPoint(
          latitude: 25.0340, // ~100m away
          longitude: 121.5654,
          accuracy: 10,
          timestamp: baseTime + 65000,
        );

        final completedStay = detector.process(leavePoint);

        expect(completedStay, isNotNull);
        expect(completedStay!.duration, greaterThanOrEqualTo(45));
      });

      test('prunes old points', () {
        final baseTime = 1000000;

        // Add points spanning 3 minutes
        for (var i = 0; i <= 180; i += 5) {
          final point = LocationPoint(
            latitude: 25.0330,
            longitude: 121.5654,
            accuracy: 10,
            timestamp: baseTime + (i * 1000),
          );
          detector.process(point);
        }

        // Should still be staying but with pruned history
        expect(detector.isStaying, isTrue);
      });
    });

    group('currentStayDuration', () {
      test('returns 0 with insufficient points', () {
        expect(detector.currentStayDuration, equals(0));

        final point = LocationPoint(
          latitude: 25.0330,
          longitude: 121.5654,
          accuracy: 10,
          timestamp: 1000000,
        );
        detector.process(point);

        expect(detector.currentStayDuration, equals(0));
      });

      test('returns correct duration', () {
        final baseTime = 1000000;

        for (var i = 0; i <= 30; i += 5) {
          final point = LocationPoint(
            latitude: 25.0330,
            longitude: 121.5654,
            accuracy: 10,
            timestamp: baseTime + (i * 1000),
          );
          detector.process(point);
        }

        expect(detector.currentStayDuration, greaterThanOrEqualTo(25));
      });
    });

    group('endCurrentStay', () {
      test('returns null if not staying', () {
        final result = detector.endCurrentStay();
        expect(result, isNull);
      });

      test('returns and clears current stay', () {
        final baseTime = 1000000;

        // Create a stay
        for (var i = 0; i <= 60; i += 5) {
          final point = LocationPoint(
            latitude: 25.0330,
            longitude: 121.5654,
            accuracy: 10,
            timestamp: baseTime + (i * 1000),
          );
          detector.process(point);
        }

        expect(detector.isStaying, isTrue);

        final stay = detector.endCurrentStay();

        expect(stay, isNotNull);
        expect(detector.isStaying, isFalse);
        expect(detector.currentStay, isNull);
      });
    });

    group('reset', () {
      test('clears all state', () {
        final baseTime = 1000000;

        // Create a stay
        for (var i = 0; i <= 60; i += 5) {
          final point = LocationPoint(
            latitude: 25.0330,
            longitude: 121.5654,
            accuracy: 10,
            timestamp: baseTime + (i * 1000),
          );
          detector.process(point);
        }

        expect(detector.isStaying, isTrue);

        detector.reset();

        expect(detector.isStaying, isFalse);
        expect(detector.currentStay, isNull);
        expect(detector.currentStayDuration, equals(0));
      });
    });
  });
}
