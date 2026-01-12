import 'package:flutter_test/flutter_test.dart';
import 'package:afterstep_fog/features/red_dot/position_obfuscator.dart';
import 'package:afterstep_fog/data/models/cell.dart';
import 'package:afterstep_fog/core/config/constants.dart';

void main() {
  group('PositionObfuscator', () {
    late PositionObfuscator obfuscator;

    setUp(() {
      obfuscator = PositionObfuscator();
    });

    group('getOffset', () {
      test('returns consistent offset for same cell ID', () {
        final offset1 = obfuscator.getOffset('cell_123');
        final offset2 = obfuscator.getOffset('cell_123');

        expect(offset1.dLat, equals(offset2.dLat));
        expect(offset1.dLng, equals(offset2.dLng));
      });

      test('returns different offset for different cell IDs', () {
        final offset1 = obfuscator.getOffset('cell_1');
        final offset2 = obfuscator.getOffset('cell_2');

        // Very unlikely to be exactly the same
        expect(
          offset1.dLat != offset2.dLat || offset1.dLng != offset2.dLng,
          isTrue,
        );
      });

      test('caches offset', () {
        final offset1 = obfuscator.getOffset('cell_123');
        obfuscator.clearCache();
        final offset2 = obfuscator.getOffset('cell_123');

        // Same cell ID should produce same offset (deterministic)
        expect(offset1.dLat, equals(offset2.dLat));
        expect(offset1.dLng, equals(offset2.dLng));
      });

      test('offset is within expected range', () {
        // Generate multiple offsets and check range
        for (var i = 0; i < 100; i++) {
          final offset = obfuscator.getOffset('cell_$i');

          // Convert offset back to approximate meters
          final dLatMeters = offset.dLat * CellConfig.metersPerLatDegree;
          final dLngMeters = offset.dLng * CellConfig.metersPerLatDegree;
          final distance =
              (dLatMeters * dLatMeters + dLngMeters * dLngMeters);

          // Distance should be within min to max range
          expect(
            distance,
            greaterThanOrEqualTo(
                RedDotConfig.offsetMinMeters * RedDotConfig.offsetMinMeters * 0.5),
          );
          expect(
            distance,
            lessThanOrEqualTo(
                RedDotConfig.offsetMaxMeters * RedDotConfig.offsetMaxMeters * 2),
          );
        }
      });
    });

    group('applyOffset', () {
      test('applies offset to cell center', () {
        final cell = Cell(
          cellId: 'test_cell',
          latIndex: 100,
          lngIndex: 200,
          centerLat: 25.0330,
          centerLng: 121.5654,
          bounds: const CellBounds(
            north: 25.034,
            south: 25.032,
            east: 121.567,
            west: 121.564,
          ),
        );

        final result = obfuscator.applyOffset(cell);

        // Result should be different from original
        expect(result.lat, isNot(equals(25.0330)));
        expect(result.lng, isNot(equals(121.5654)));

        // But not too far
        expect((result.lat - 25.0330).abs(), lessThan(0.001));
        expect((result.lng - 121.5654).abs(), lessThan(0.001));
      });

      test('returns consistent results for same cell', () {
        final cell = Cell(
          cellId: 'test_cell',
          latIndex: 100,
          lngIndex: 200,
          centerLat: 25.0330,
          centerLng: 121.5654,
          bounds: const CellBounds(
            north: 25.034,
            south: 25.032,
            east: 121.567,
            west: 121.564,
          ),
        );

        final result1 = obfuscator.applyOffset(cell);
        final result2 = obfuscator.applyOffset(cell);

        expect(result1.lat, equals(result2.lat));
        expect(result1.lng, equals(result2.lng));
      });
    });

    group('applyOffsetToCoord', () {
      test('applies offset to coordinates', () {
        final result = obfuscator.applyOffsetToCoord(
          'test_cell',
          25.0330,
          121.5654,
        );

        expect(result.lat, isNot(equals(25.0330)));
        expect(result.lng, isNot(equals(121.5654)));
      });

      test('uses same offset as getOffset', () {
        const cellId = 'test_cell';
        const lat = 25.0330;
        const lng = 121.5654;

        final offset = obfuscator.getOffset(cellId);
        final result = obfuscator.applyOffsetToCoord(cellId, lat, lng);

        expect(result.lat, equals(lat + offset.dLat));
        expect(result.lng, equals(lng + offset.dLng));
      });
    });

    group('clearCache', () {
      test('clears offset cache', () {
        // Pre-populate cache
        obfuscator.getOffset('cell_1');
        obfuscator.getOffset('cell_2');

        obfuscator.clearCache();

        // After clearing, offsets should still be deterministic
        final offset1 = obfuscator.getOffset('cell_1');
        final offset2 = obfuscator.getOffset('cell_1');

        expect(offset1.dLat, equals(offset2.dLat));
      });
    });
  });
}
