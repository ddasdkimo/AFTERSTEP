import 'package:flutter_test/flutter_test.dart';
import 'package:afterstep_fog/features/red_dot/intensity_calculator.dart';
import 'package:afterstep_fog/data/models/cell.dart';
import 'package:afterstep_fog/core/config/constants.dart';

void main() {
  group('IntensityCalculator', () {
    late IntensityCalculator calculator;

    setUp(() {
      calculator = IntensityCalculator();
    });

    group('calculate', () {
      test('returns 1.0 for current time', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final intensity = calculator.calculate(now);

        expect(intensity, closeTo(1.0, 0.01));
      });

      test('returns decreasing value for older times', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final oneHourAgo = now - (60 * 60 * 1000);
        final oneDayAgo = now - (24 * 60 * 60 * 1000);

        final intensityNow = calculator.calculate(now);
        final intensityHour = calculator.calculate(oneHourAgo);
        final intensityDay = calculator.calculate(oneDayAgo);

        expect(intensityHour, lessThan(intensityNow));
        expect(intensityDay, lessThan(intensityHour));
      });

      test('follows exponential decay', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final tauDays = RedDotConfig.decayTauDays;
        final tauMs = (tauDays * 24 * 60 * 60 * 1000).round();

        // At time τ, intensity should be ~1/e ≈ 0.368
        final atTau = now - tauMs;
        final intensityAtTau = calculator.calculate(atTau);

        expect(intensityAtTau, closeTo(0.368, 0.02));
      });

      test('returns 1.0 for future times', () {
        final future = DateTime.now().millisecondsSinceEpoch + 10000;
        final intensity = calculator.calculate(future);

        expect(intensity, equals(1.0));
      });
    });

    group('processActivities', () {
      test('returns empty map for empty input', () {
        final result = calculator.processActivities([]);
        expect(result, isEmpty);
      });

      test('includes recent activities', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final activities = [
          CellActivity(cellId: 'cell_1', lastActivityTime: now),
          CellActivity(cellId: 'cell_2', lastActivityTime: now - 10000),
        ];

        final result = calculator.processActivities(activities);

        expect(result.containsKey('cell_1'), isTrue);
        expect(result.containsKey('cell_2'), isTrue);
      });

      test('excludes old activities below threshold', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        // Activity from long ago (beyond max valid time)
        final veryOld = now - calculator.maxValidDeltaMs - 10000;
        final activities = [
          CellActivity(cellId: 'cell_1', lastActivityTime: now),
          CellActivity(cellId: 'cell_2', lastActivityTime: veryOld),
        ];

        final result = calculator.processActivities(activities);

        expect(result.containsKey('cell_1'), isTrue);
        expect(result.containsKey('cell_2'), isFalse);
      });

      test('calculates correct intensities', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final activities = [
          CellActivity(cellId: 'cell_1', lastActivityTime: now),
        ];

        final result = calculator.processActivities(activities);

        expect(result['cell_1'], closeTo(1.0, 0.01));
      });
    });

    group('isActivityValid', () {
      test('returns true for recent activity', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        expect(calculator.isActivityValid(now), isTrue);
      });

      test('returns false for very old activity', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final veryOld = now - calculator.maxValidDeltaMs - 10000;
        expect(calculator.isActivityValid(veryOld), isFalse);
      });
    });

    group('maxValidDeltaMs', () {
      test('returns positive value', () {
        expect(calculator.maxValidDeltaMs, greaterThan(0));
      });

      test('corresponds to threshold intensity', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final atMaxDelta = now - calculator.maxValidDeltaMs;
        final intensity = calculator.calculate(atMaxDelta);

        expect(intensity, closeTo(RedDotConfig.intensityThreshold, 0.01));
      });
    });
  });
}
