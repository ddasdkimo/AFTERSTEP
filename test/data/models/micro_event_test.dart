import 'package:flutter_test/flutter_test.dart';
import 'package:afterstep_fog/data/models/micro_event.dart';

void main() {
  group('EventCategory', () {
    test('has all expected values', () {
      expect(EventCategory.values.length, equals(4));
      expect(EventCategory.presence, isNotNull);
      expect(EventCategory.time, isNotNull);
      expect(EventCategory.space, isNotNull);
      expect(EventCategory.connection, isNotNull);
    });
  });

  group('MicroEventDefinition', () {
    test('creates with required properties', () {
      const definition = MicroEventDefinition(
        id: 'event_1',
        text: 'Test text',
        category: EventCategory.presence,
        weight: 10,
      );

      expect(definition.id, equals('event_1'));
      expect(definition.text, equals('Test text'));
      expect(definition.category, equals(EventCategory.presence));
      expect(definition.weight, equals(10));
    });

    test('equality works correctly', () {
      const def1 = MicroEventDefinition(
        id: 'event_1',
        text: 'Test text',
        category: EventCategory.presence,
        weight: 10,
      );
      const def2 = MicroEventDefinition(
        id: 'event_1',
        text: 'Test text',
        category: EventCategory.presence,
        weight: 10,
      );
      const def3 = MicroEventDefinition(
        id: 'event_2',
        text: 'Test text',
        category: EventCategory.presence,
        weight: 10,
      );

      expect(def1, equals(def2));
      expect(def1, isNot(equals(def3)));
    });
  });

  group('TriggerContext', () {
    test('creates with required properties', () {
      const context = TriggerContext(
        cellId: 'cell_1',
        stayDuration: 60,
        hasRedDot: true,
        timestamp: 1000000,
      );

      expect(context.cellId, equals('cell_1'));
      expect(context.stayDuration, equals(60));
      expect(context.hasRedDot, isTrue);
      expect(context.timestamp, equals(1000000));
    });

    test('creates with optional red dot intensity', () {
      const context = TriggerContext(
        cellId: 'cell_1',
        stayDuration: 60,
        hasRedDot: true,
        redDotIntensity: 0.8,
        timestamp: 1000000,
      );

      expect(context.redDotIntensity, equals(0.8));
    });

    test('equality works correctly', () {
      const ctx1 = TriggerContext(
        cellId: 'cell_1',
        stayDuration: 60,
        hasRedDot: true,
        timestamp: 1000000,
      );
      const ctx2 = TriggerContext(
        cellId: 'cell_1',
        stayDuration: 60,
        hasRedDot: true,
        timestamp: 1000000,
      );

      expect(ctx1, equals(ctx2));
    });
  });

  group('CooldownState', () {
    test('creates empty state', () {
      const state = CooldownState.empty;

      expect(state.cellCooldowns, isEmpty);
      expect(state.dailyCount, equals(0));
      expect(state.dailyResetTime, equals(0));
    });

    test('creates with properties', () {
      final state = CooldownState(
        cellCooldowns: {'cell_1': 1000000},
        dailyCount: 5,
        dailyResetTime: 2000000,
      );

      expect(state.cellCooldowns['cell_1'], equals(1000000));
      expect(state.dailyCount, equals(5));
      expect(state.dailyResetTime, equals(2000000));
    });

    test('serializes to map', () {
      final state = CooldownState(
        cellCooldowns: {'cell_1': 1000000},
        dailyCount: 5,
        dailyResetTime: 2000000,
      );

      final map = state.toMap();

      expect(map['cell_cooldowns'], equals({'cell_1': 1000000}));
      expect(map['daily_count'], equals(5));
      expect(map['daily_reset_time'], equals(2000000));
    });

    test('deserializes from map', () {
      final map = {
        'cell_cooldowns': {'cell_1': 1000000},
        'daily_count': 5,
        'daily_reset_time': 2000000,
      };

      final state = CooldownState.fromMap(map);

      expect(state.cellCooldowns['cell_1'], equals(1000000));
      expect(state.dailyCount, equals(5));
    });

    test('deserializes with null values', () {
      final map = <String, dynamic>{};

      final state = CooldownState.fromMap(map);

      expect(state.cellCooldowns, isEmpty);
      expect(state.dailyCount, equals(0));
    });

    test('copyWith creates modified copy', () {
      const original = CooldownState.empty;

      final modified = original.copyWith(dailyCount: 3);

      expect(modified.dailyCount, equals(3));
      expect(modified.cellCooldowns, isEmpty);
    });
  });

  group('DisplayPhase', () {
    test('has all expected values', () {
      expect(DisplayPhase.values.length, equals(4));
      expect(DisplayPhase.fadeIn, isNotNull);
      expect(DisplayPhase.visible, isNotNull);
      expect(DisplayPhase.fadeOut, isNotNull);
      expect(DisplayPhase.done, isNotNull);
    });
  });

  group('DisplayEvent', () {
    test('creates with required properties', () {
      const event = DisplayEvent(
        id: 'display_1',
        text: 'Display text',
        startTime: 1000000,
        phase: DisplayPhase.fadeIn,
      );

      expect(event.id, equals('display_1'));
      expect(event.text, equals('Display text'));
      expect(event.startTime, equals(1000000));
      expect(event.phase, equals(DisplayPhase.fadeIn));
    });

    test('copyWith creates modified copy', () {
      const original = DisplayEvent(
        id: 'display_1',
        text: 'Display text',
        startTime: 1000000,
        phase: DisplayPhase.fadeIn,
      );

      final modified = original.copyWith(phase: DisplayPhase.visible);

      expect(modified.id, equals('display_1'));
      expect(modified.phase, equals(DisplayPhase.visible));
    });

    test('equality works correctly', () {
      const event1 = DisplayEvent(
        id: 'display_1',
        text: 'Display text',
        startTime: 1000000,
        phase: DisplayPhase.fadeIn,
      );
      const event2 = DisplayEvent(
        id: 'display_1',
        text: 'Display text',
        startTime: 1000000,
        phase: DisplayPhase.fadeIn,
      );

      expect(event1, equals(event2));
    });
  });
}
