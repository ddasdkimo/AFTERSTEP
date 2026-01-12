import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:afterstep_fog/features/push/push_messages.dart';

void main() {
  group('PushMessage', () {
    test('has required properties', () {
      const message = PushMessage(
        id: 'test_1',
        body: 'Test message body',
        weight: 10,
      );

      expect(message.id, equals('test_1'));
      expect(message.body, equals('Test message body'));
      expect(message.weight, equals(10));
    });
  });

  group('pushMessages', () {
    test('contains messages', () {
      expect(pushMessages, isNotEmpty);
    });

    test('all messages have valid properties', () {
      for (final message in pushMessages) {
        expect(message.id, isNotEmpty);
        expect(message.body, isNotEmpty);
        expect(message.weight, greaterThan(0));
      }
    });

    test('all messages have unique IDs', () {
      final ids = pushMessages.map((m) => m.id).toSet();
      expect(ids.length, equals(pushMessages.length));
    });
  });

  group('PushMessageSelector', () {
    group('select', () {
      test('returns a message', () {
        final selector = PushMessageSelector();
        final message = selector.select();

        expect(message, isNotNull);
        expect(message.body, isNotEmpty);
      });

      test('returns different messages over multiple selections', () {
        final selector = PushMessageSelector();
        final messages = <String>{};

        for (var i = 0; i < 20; i++) {
          messages.add(selector.select().body);
        }

        // Should have some variety (unless all weights are same)
        expect(messages.length, greaterThan(1));
      });

      test('avoids recently used messages', () {
        final selector = PushMessageSelector();
        final recentMessages = <String>[];

        for (var i = 0; i < 5; i++) {
          final message = selector.select();
          recentMessages.add(message.id);
        }

        // Check consecutive messages are different
        for (var i = 1; i < recentMessages.length; i++) {
          expect(recentMessages[i], isNot(equals(recentMessages[i - 1])));
        }
      });

      test('respects message weights', () {
        // Create messages with very different weights
        final messages = [
          const PushMessage(id: 'high', body: 'High weight', weight: 100),
          const PushMessage(id: 'low', body: 'Low weight', weight: 1),
        ];

        final selector = PushMessageSelector(
          messages: messages,
          random: math.Random(42),
        );

        var highCount = 0;
        var lowCount = 0;

        for (var i = 0; i < 100; i++) {
          final message = selector.select();
          if (message.id == 'high') {
            highCount++;
          } else {
            lowCount++;
          }
        }

        // High weight message should be selected more often
        expect(highCount, greaterThan(lowCount));
      });
    });

    group('resetRecentlyUsed', () {
      test('clears recent usage tracking', () {
        final selector = PushMessageSelector();

        // Use selector multiple times
        for (var i = 0; i < 3; i++) {
          selector.select();
        }

        selector.resetRecentlyUsed();

        // After reset, all messages should be available again
        final message = selector.select();
        expect(message, isNotNull);
      });
    });

    group('with custom messages', () {
      test('uses provided messages', () {
        final customMessages = [
          const PushMessage(id: 'custom_1', body: 'Custom 1', weight: 10),
          const PushMessage(id: 'custom_2', body: 'Custom 2', weight: 10),
        ];

        final selector = PushMessageSelector(messages: customMessages);
        final bodies = <String>{};

        for (var i = 0; i < 20; i++) {
          bodies.add(selector.select().body);
        }

        for (final body in bodies) {
          expect(body == 'Custom 1' || body == 'Custom 2', isTrue);
        }
      });
    });

    group('deterministic with seeded random', () {
      test('produces same sequence with same seed', () {
        final selector1 = PushMessageSelector(random: math.Random(42));
        final selector2 = PushMessageSelector(random: math.Random(42));

        for (var i = 0; i < 10; i++) {
          expect(selector1.select().id, equals(selector2.select().id));
        }
      });
    });
  });
}
