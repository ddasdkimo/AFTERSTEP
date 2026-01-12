import 'package:flutter_test/flutter_test.dart';
import 'package:afterstep_fog/features/micro_event/cooldown_manager.dart';
import 'package:afterstep_fog/core/config/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CooldownManager', () {
    late CooldownManager manager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      manager = CooldownManager();
      await manager.initialize();
    });

    group('canTrigger', () {
      test('allows trigger for new cell', () {
        final result = manager.canTrigger('new_cell_id');
        expect(result.allowed, isTrue);
      });

      test('blocks trigger for cell in cooldown', () {
        manager.recordTrigger('cell_1');
        final result = manager.canTrigger('cell_1');
        expect(result.allowed, isFalse);
      });

      test('allows different cell after one is blocked', () {
        manager.recordTrigger('cell_1');

        final result1 = manager.canTrigger('cell_1');
        final result2 = manager.canTrigger('cell_2');

        expect(result1.allowed, isFalse);
        expect(result2.allowed, isTrue);
      });
    });

    group('recordTrigger', () {
      test('tracks cell trigger', () {
        manager.recordTrigger('cell_1');

        final result = manager.canTrigger('cell_1');
        expect(result.allowed, isFalse);
      });

      test('increments daily count', () {
        final initialRemaining = manager.getRemainingToday();

        manager.recordTrigger('cell_1');

        final afterRemaining = manager.getRemainingToday();
        expect(afterRemaining, equals(initialRemaining - 1));
      });
    });

    group('daily limit', () {
      test('respects daily maximum', () {
        // Trigger up to daily limit
        for (var i = 0; i < MicroEventConfig.dailyMaxEvents; i++) {
          final canTrigger = manager.canTrigger('cell_$i');
          if (canTrigger.allowed) {
            manager.recordTrigger('cell_$i');
          }
        }

        // Next trigger should be blocked
        final result = manager.canTrigger('cell_next');
        expect(result.allowed, isFalse);
      });

      test('getRemainingToday returns correct count', () {
        expect(
          manager.getRemainingToday(),
          equals(MicroEventConfig.dailyMaxEvents),
        );

        manager.recordTrigger('cell_1');

        expect(
          manager.getRemainingToday(),
          equals(MicroEventConfig.dailyMaxEvents - 1),
        );
      });
    });

    group('reset', () {
      test('clears all cooldowns', () async {
        manager.recordTrigger('cell_1');
        manager.recordTrigger('cell_2');

        await manager.reset();

        expect(manager.canTrigger('cell_1').allowed, isTrue);
        expect(manager.canTrigger('cell_2').allowed, isTrue);
      });

      test('resets daily count', () async {
        manager.recordTrigger('cell_1');
        final before = manager.getRemainingToday();

        await manager.reset();
        final after = manager.getRemainingToday();

        expect(after, greaterThan(before));
      });
    });

    group('cooldown expiry', () {
      test('provides remaining cooldown time', () {
        manager.recordTrigger('cell_1');

        final result = manager.canTrigger('cell_1');
        expect(result.allowed, isFalse);
        expect(result.reason, equals('cell_cooldown'));

        // Check remaining time via getCellCooldownRemaining
        final remaining = manager.getCellCooldownRemaining('cell_1');
        expect(remaining, isNotNull);
        expect(remaining, greaterThan(0));
      });
    });
  });
}
