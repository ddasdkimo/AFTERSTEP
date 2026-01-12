import 'package:flutter_test/flutter_test.dart';
import 'package:afterstep_fog/features/cell/cell_cache.dart';
import 'package:afterstep_fog/data/models/cell.dart';

void main() {
  group('CellCache', () {
    late CellCache cache;

    setUp(() {
      cache = CellCache();
    });

    test('stores and retrieves cell state', () {
      final state = UserCellState(
        cellId: 'test_cell_1',
        unlocked: true,
        unlockedAt: DateTime.now().millisecondsSinceEpoch,
      );

      cache.set('test_cell_1', state);
      final retrieved = cache.get('test_cell_1');

      expect(retrieved, isNotNull);
      expect(retrieved!.cellId, equals('test_cell_1'));
      expect(retrieved.unlocked, isTrue);
    });

    test('returns null for non-existent cell', () {
      final result = cache.get('non_existent');
      expect(result, isNull);
    });

    test('contains returns true for cached cell', () {
      final state = UserCellState(cellId: 'test_cell_1', unlocked: false);
      cache.set('test_cell_1', state);

      expect(cache.contains('test_cell_1'), isTrue);
      expect(cache.contains('non_existent'), isFalse);
    });

    test('updates existing cell state', () {
      final state1 = UserCellState(cellId: 'test_cell_1', unlocked: false);
      cache.set('test_cell_1', state1);

      final state2 = UserCellState(
        cellId: 'test_cell_1',
        unlocked: true,
        unlockedAt: 12345,
      );
      cache.set('test_cell_1', state2);

      final retrieved = cache.get('test_cell_1');
      expect(retrieved!.unlocked, isTrue);
      expect(retrieved.unlockedAt, equals(12345));
    });

    test('clear removes all cached states', () {
      cache.set('cell_1', UserCellState(cellId: 'cell_1', unlocked: true));
      cache.set('cell_2', UserCellState(cellId: 'cell_2', unlocked: false));

      cache.clear();

      expect(cache.contains('cell_1'), isFalse);
      expect(cache.contains('cell_2'), isFalse);
    });

    test('handles multiple cells', () {
      for (var i = 0; i < 10; i++) {
        cache.set('cell_$i', UserCellState(cellId: 'cell_$i', unlocked: i.isEven));
      }

      expect(cache.get('cell_0')!.unlocked, isTrue);
      expect(cache.get('cell_1')!.unlocked, isFalse);
      expect(cache.get('cell_8')!.unlocked, isTrue);
      expect(cache.get('cell_9')!.unlocked, isFalse);
    });
  });
}
