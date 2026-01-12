import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:afterstep_fog/core/utils/geo_utils.dart';

void main() {
  group('GeoUtils', () {
    group('haversineDistance', () {
      test('returns 0 for same point', () {
        final distance = GeoUtils.haversineDistance(
          25.0330,
          121.5654,
          25.0330,
          121.5654,
        );
        expect(distance, equals(0));
      });

      test('calculates correct distance for known points', () {
        // Taipei 101 to Taipei Main Station: approximately 2.5km
        final distance = GeoUtils.haversineDistance(
          25.0330, // Taipei 101
          121.5654,
          25.0478, // Taipei Main Station
          121.5170,
        );
        // Should be roughly 2.5km (allowing 10% margin)
        expect(distance, greaterThan(4500));
        expect(distance, lessThan(5500));
      });

      test('handles negative coordinates', () {
        final distance = GeoUtils.haversineDistance(
          -33.8688, // Sydney
          151.2093,
          -37.8136, // Melbourne
          144.9631,
        );
        // Sydney to Melbourne is about 714km
        expect(distance, greaterThan(700000));
        expect(distance, lessThan(720000));
      });

      test('is symmetric', () {
        final d1 = GeoUtils.haversineDistance(25.0, 121.0, 26.0, 122.0);
        final d2 = GeoUtils.haversineDistance(26.0, 122.0, 25.0, 121.0);
        expect(d1, closeTo(d2, 0.001));
      });
    });

    group('metersPerLngDegree', () {
      test('returns metersPerLatDegree at equator', () {
        final meters = GeoUtils.metersPerLngDegree(0);
        expect(meters, closeTo(GeoUtils.metersPerLatDegree, 10));
      });

      test('returns 0 at poles', () {
        final metersNorth = GeoUtils.metersPerLngDegree(90);
        expect(metersNorth, closeTo(0, 10));
      });

      test('decreases with latitude', () {
        final metersAt0 = GeoUtils.metersPerLngDegree(0);
        final metersAt45 = GeoUtils.metersPerLngDegree(45);
        final metersAt60 = GeoUtils.metersPerLngDegree(60);

        expect(metersAt45, lessThan(metersAt0));
        expect(metersAt60, lessThan(metersAt45));
      });
    });

    group('geoToMercator', () {
      test('converts coordinates at zoom 0', () {
        final result = GeoUtils.geoToMercator(0, 0, 0);
        expect(result.x, closeTo(128, 1));
        expect(result.y, closeTo(128, 1));
      });

      test('increases scale with zoom', () {
        final zoom0 = GeoUtils.geoToMercator(25.0330, 121.5654, 0);
        final zoom1 = GeoUtils.geoToMercator(25.0330, 121.5654, 1);

        expect(zoom1.x, closeTo(zoom0.x * 2, 1));
      });
    });

    group('metersToPixels', () {
      test('converts meters to pixels', () {
        final pixels = GeoUtils.metersToPixels(100, 25.0330, 16);
        expect(pixels, greaterThan(0));
      });

      test('increases with zoom level', () {
        final pixelsZoom15 = GeoUtils.metersToPixels(100, 25.0330, 15);
        final pixelsZoom16 = GeoUtils.metersToPixels(100, 25.0330, 16);

        expect(pixelsZoom16, closeTo(pixelsZoom15 * 2, 0.01));
      });
    });

    group('pixelsToMeters', () {
      test('is inverse of metersToPixels', () {
        const originalMeters = 100.0;
        const latitude = 25.0330;
        const zoom = 16.0;

        final pixels = GeoUtils.metersToPixels(originalMeters, latitude, zoom);
        final meters = GeoUtils.pixelsToMeters(pixels, latitude, zoom);

        expect(meters, closeTo(originalMeters, 0.01));
      });
    });

    group('offsetCoordinate', () {
      test('offsets north correctly', () {
        final result = GeoUtils.offsetCoordinate(
          25.0330,
          121.5654,
          1000, // 1km
          0, // north
        );

        expect(result.lat, greaterThan(25.0330));
        expect(result.lng, closeTo(121.5654, 0.001));
      });

      test('offsets east correctly', () {
        final result = GeoUtils.offsetCoordinate(
          25.0330,
          121.5654,
          1000, // 1km
          math.pi / 2, // east
        );

        expect(result.lat, closeTo(25.0330, 0.01));
        expect(result.lng, greaterThan(121.5654));
      });

      test('offsets south correctly', () {
        final result = GeoUtils.offsetCoordinate(
          25.0330,
          121.5654,
          1000, // 1km
          math.pi, // south
        );

        expect(result.lat, lessThan(25.0330));
        expect(result.lng, closeTo(121.5654, 0.001));
      });
    });

    group('bearing', () {
      test('returns 0 for point due north', () {
        final b = GeoUtils.bearing(25.0, 121.0, 26.0, 121.0);
        expect(b, closeTo(0, 0.1));
      });

      test('returns pi/2 for point due east', () {
        final b = GeoUtils.bearing(25.0, 121.0, 25.0, 122.0);
        expect(b, closeTo(math.pi / 2, 0.1));
      });
    });

    group('simpleOffset', () {
      test('offsets latitude correctly', () {
        final result = GeoUtils.simpleOffset(25.0330, 121.5654, 1000, 0);

        expect(result.lat, greaterThan(25.0330));
        expect(result.lng, closeTo(121.5654, 0.0001));
      });

      test('offsets longitude correctly', () {
        final result = GeoUtils.simpleOffset(25.0330, 121.5654, 0, 1000);

        expect(result.lat, closeTo(25.0330, 0.0001));
        expect(result.lng, greaterThan(121.5654));
      });

      test('handles negative offsets', () {
        final result = GeoUtils.simpleOffset(25.0330, 121.5654, -1000, -1000);

        expect(result.lat, lessThan(25.0330));
        expect(result.lng, lessThan(121.5654));
      });
    });
  });
}
