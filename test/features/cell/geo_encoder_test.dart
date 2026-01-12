import 'package:flutter_test/flutter_test.dart';
import 'package:afterstep_fog/features/cell/geo_encoder.dart';
import 'package:afterstep_fog/core/config/constants.dart';

void main() {
  group('GeoEncoder', () {
    late GeoEncoder encoder;

    setUp(() {
      encoder = GeoEncoder();
    });

    group('coordToCell', () {
      test('returns cell for valid coordinates', () {
        final cell = encoder.coordToCell(25.0330, 121.5654);

        expect(cell.cellId, isNotEmpty);
        expect(cell.latIndex, isA<int>());
        expect(cell.lngIndex, isA<int>());
        expect(cell.centerLat, isA<double>());
        expect(cell.centerLng, isA<double>());
      });

      test('returns same cell for nearby coordinates', () {
        final cell1 = encoder.coordToCell(25.0330, 121.5654);
        final cell2 = encoder.coordToCell(25.03305, 121.56545);

        expect(cell1.cellId, equals(cell2.cellId));
      });

      test('returns different cell for distant coordinates', () {
        final cell1 = encoder.coordToCell(25.0330, 121.5654);
        final cell2 = encoder.coordToCell(25.0350, 121.5654); // ~200m away

        expect(cell1.cellId, isNot(equals(cell2.cellId)));
      });

      test('calculates correct cell bounds', () {
        final cell = encoder.coordToCell(25.0330, 121.5654);

        expect(cell.bounds.north, greaterThan(cell.bounds.south));
        expect(cell.bounds.east, greaterThan(cell.bounds.west));
        expect(cell.centerLat, greaterThan(cell.bounds.south));
        expect(cell.centerLat, lessThan(cell.bounds.north));
        expect(cell.centerLng, greaterThan(cell.bounds.west));
        expect(cell.centerLng, lessThan(cell.bounds.east));
      });
    });

    group('indexToCell', () {
      test('creates cell from indices', () {
        final cell = encoder.indexToCell(100, 200, 25.0);

        expect(cell.cellId, equals('100:200'));
        expect(cell.latIndex, equals(100));
        expect(cell.lngIndex, equals(200));
      });

      test('is consistent with coordToCell', () {
        final originalCell = encoder.coordToCell(25.0330, 121.5654);
        final recreatedCell = encoder.indexToCell(
          originalCell.latIndex,
          originalCell.lngIndex,
          25.0330,
        );

        expect(recreatedCell.cellId, equals(originalCell.cellId));
      });
    });

    group('parseCellId', () {
      test('parses valid cell ID', () {
        final result = encoder.parseCellId('100:200');

        expect(result.latIndex, equals(100));
        expect(result.lngIndex, equals(200));
      });

      test('parses negative indices', () {
        final result = encoder.parseCellId('-50:-100');

        expect(result.latIndex, equals(-50));
        expect(result.lngIndex, equals(-100));
      });
    });

    group('cellIdToCell', () {
      test('creates cell from cell ID', () {
        final cell = encoder.cellIdToCell('100:200', 25.0);

        expect(cell.cellId, equals('100:200'));
        expect(cell.latIndex, equals(100));
        expect(cell.lngIndex, equals(200));
      });
    });
  });

  group('CellQueryService', () {
    late CellQueryService queryService;

    setUp(() {
      queryService = CellQueryService();
    });

    group('getNearbyCells', () {
      test('returns cells including center', () {
        final cells = queryService.getNearbyCells(25.0330, 121.5654, radius: 1);

        expect(cells.length, equals(9)); // 3x3 grid
      });

      test('returns more cells with larger radius', () {
        final cells1 = queryService.getNearbyCells(25.0330, 121.5654, radius: 1);
        final cells2 = queryService.getNearbyCells(25.0330, 121.5654, radius: 2);

        expect(cells2.length, greaterThan(cells1.length));
      });

      test('default radius matches config', () {
        final cells = queryService.getNearbyCells(25.0330, 121.5654);
        final expectedCount =
            (2 * CellConfig.nearbyRadius + 1) * (2 * CellConfig.nearbyRadius + 1);

        expect(cells.length, equals(expectedCount));
      });
    });

    group('getCellsAlongPath', () {
      test('returns at least start and end cells', () {
        final cells = queryService.getCellsAlongPath(
          25.0330,
          121.5654,
          25.0330,
          121.5654,
        );

        expect(cells.length, greaterThanOrEqualTo(1));
      });

      test('returns cells along path', () {
        final cells = queryService.getCellsAlongPath(
          25.0330,
          121.5654,
          25.0350, // ~200m away
          121.5654,
        );

        expect(cells.length, greaterThan(1));
      });

      test('returns unique cells', () {
        final cells = queryService.getCellsAlongPath(
          25.0330,
          121.5654,
          25.0350,
          121.5654,
        );

        final ids = cells.map((c) => c.cellId).toSet();
        expect(ids.length, equals(cells.length));
      });
    });

    group('getCellIdsInBounds', () {
      test('returns cells within bounds', () {
        final cellIds = queryService.getCellIdsInBounds(
          25.034, // north
          25.032, // south
          121.567, // east
          121.564, // west
        );

        expect(cellIds, isNotEmpty);
      });

      test('returns more cells for larger bounds', () {
        final smallBounds = queryService.getCellIdsInBounds(
          25.034,
          25.033,
          121.566,
          121.565,
        );
        final largeBounds = queryService.getCellIdsInBounds(
          25.040,
          25.030,
          121.570,
          121.560,
        );

        expect(largeBounds.length, greaterThan(smallBounds.length));
      });
    });
  });
}
