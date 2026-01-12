import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:afterstep_fog/features/micro_event/text_selector.dart';
import 'package:afterstep_fog/data/models/micro_event.dart';

void main() {
  group('TextSelector', () {
    group('select', () {
      test('returns a valid event', () {
        final selector = TextSelector();
        final context = TriggerContext(
          cellId: 'cell_1',
          stayDuration: 60,
          hasRedDot: false,
          timestamp: 1000000,
        );

        final event = selector.select(context);

        expect(event.id, isNotEmpty);
        expect(event.text, isNotEmpty);
        expect(event.weight, greaterThan(0));
      });

      test('avoids recently used events', () {
        final customEvents = [
          const MicroEventDefinition(
            id: 'event_1',
            text: 'Text 1',
            category: EventCategory.presence,
            weight: 10,
          ),
          const MicroEventDefinition(
            id: 'event_2',
            text: 'Text 2',
            category: EventCategory.time,
            weight: 10,
          ),
          const MicroEventDefinition(
            id: 'event_3',
            text: 'Text 3',
            category: EventCategory.space,
            weight: 10,
          ),
        ];

        final selector = TextSelector(
          events: customEvents,
          random: math.Random(42),
        );

        final context = TriggerContext(
          cellId: 'cell_1',
          stayDuration: 60,
          hasRedDot: false,
          timestamp: 1000000,
        );

        final recentIds = <String>[];
        for (var i = 0; i < 3; i++) {
          final event = selector.select(context);
          // Each selection should be different from the previous one
          if (recentIds.isNotEmpty) {
            expect(event.id, isNot(equals(recentIds.last)));
          }
          recentIds.add(event.id);
        }
      });

      test('prefers connection category with high red dot intensity', () {
        final customEvents = [
          const MicroEventDefinition(
            id: 'connection_1',
            text: 'Connection text',
            category: EventCategory.connection,
            weight: 10,
          ),
          const MicroEventDefinition(
            id: 'other_1',
            text: 'Other text',
            category: EventCategory.presence,
            weight: 10,
          ),
        ];

        final selector = TextSelector(events: customEvents);

        final contextHighRedDot = TriggerContext(
          cellId: 'cell_1',
          stayDuration: 60,
          hasRedDot: true,
          redDotIntensity: 0.9,
          timestamp: 1000000,
        );

        var connectionCount = 0;
        for (var i = 0; i < 100; i++) {
          final event = selector.select(contextHighRedDot);
          if (event.category == EventCategory.connection) {
            connectionCount++;
          }
          selector.resetRecentlyUsed();
        }

        // Connection category should be selected more often (with 1.5x weight boost)
        // Expected: 100 * (15/25) ≈ 60, but allow for randomness
        expect(connectionCount, greaterThan(45));
      });

      test('prefers time category with long stay duration', () {
        final customEvents = [
          const MicroEventDefinition(
            id: 'time_1',
            text: 'Time text',
            category: EventCategory.time,
            weight: 10,
          ),
          const MicroEventDefinition(
            id: 'other_1',
            text: 'Other text',
            category: EventCategory.presence,
            weight: 10,
          ),
        ];

        final selector = TextSelector(events: customEvents);

        final contextLongStay = TriggerContext(
          cellId: 'cell_1',
          stayDuration: 120, // Long stay
          hasRedDot: false,
          timestamp: 1000000,
        );

        var timeCount = 0;
        for (var i = 0; i < 100; i++) {
          final event = selector.select(contextLongStay);
          if (event.category == EventCategory.time) {
            timeCount++;
          }
          selector.resetRecentlyUsed();
        }

        // Time category should be selected more often (with 1.3x weight boost)
        // Expected: 100 * (13/23) ≈ 57, but allow for randomness
        expect(timeCount, greaterThan(45));
      });
    });

    group('resetRecentlyUsed', () {
      test('clears recent usage tracking', () {
        final customEvents = [
          const MicroEventDefinition(
            id: 'event_1',
            text: 'Text 1',
            category: EventCategory.presence,
            weight: 100,
          ),
          const MicroEventDefinition(
            id: 'event_2',
            text: 'Text 2',
            category: EventCategory.time,
            weight: 1,
          ),
        ];

        final selector = TextSelector(
          events: customEvents,
          random: math.Random(42),
        );

        final context = TriggerContext(
          cellId: 'cell_1',
          stayDuration: 60,
          hasRedDot: false,
          timestamp: 1000000,
        );

        // Select multiple times
        for (var i = 0; i < 3; i++) {
          selector.select(context);
        }

        selector.resetRecentlyUsed();

        // After reset, should still work
        final event = selector.select(context);
        expect(event, isNotNull);
      });
    });

    group('deterministic with seeded random', () {
      test('produces same sequence with same seed', () {
        final customEvents = [
          const MicroEventDefinition(
            id: 'event_1',
            text: 'Text 1',
            category: EventCategory.presence,
            weight: 10,
          ),
          const MicroEventDefinition(
            id: 'event_2',
            text: 'Text 2',
            category: EventCategory.time,
            weight: 10,
          ),
          const MicroEventDefinition(
            id: 'event_3',
            text: 'Text 3',
            category: EventCategory.space,
            weight: 10,
          ),
        ];

        final selector1 = TextSelector(
          events: customEvents,
          random: math.Random(42),
        );
        final selector2 = TextSelector(
          events: customEvents,
          random: math.Random(42),
        );

        final context = TriggerContext(
          cellId: 'cell_1',
          stayDuration: 60,
          hasRedDot: false,
          timestamp: 1000000,
        );

        for (var i = 0; i < 10; i++) {
          expect(
            selector1.select(context).id,
            equals(selector2.select(context).id),
          );
        }
      });
    });
  });
}
