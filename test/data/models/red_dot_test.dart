import 'package:flutter_test/flutter_test.dart';
import 'package:afterstep_fog/data/models/red_dot.dart';

void main() {
  group('RedDot', () {
    test('creates with required properties', () {
      const redDot = RedDot(
        id: 'red_dot_1',
        cellId: 'cell_1',
        originalLat: 25.0330,
        originalLng: 121.5654,
        displayLat: 25.0331,
        displayLng: 121.5655,
        intensity: 0.8,
        size: 10.0,
        opacity: 0.7,
        pulsePhase: 0.5,
      );

      expect(redDot.id, equals('red_dot_1'));
      expect(redDot.cellId, equals('cell_1'));
      expect(redDot.originalLat, equals(25.0330));
      expect(redDot.originalLng, equals(121.5654));
      expect(redDot.displayLat, equals(25.0331));
      expect(redDot.displayLng, equals(121.5655));
      expect(redDot.intensity, equals(0.8));
      expect(redDot.size, equals(10.0));
      expect(redDot.opacity, equals(0.7));
      expect(redDot.pulsePhase, equals(0.5));
    });

    test('copyWith creates modified copy', () {
      const original = RedDot(
        id: 'red_dot_1',
        cellId: 'cell_1',
        originalLat: 25.0330,
        originalLng: 121.5654,
        displayLat: 25.0331,
        displayLng: 121.5655,
        intensity: 0.8,
        size: 10.0,
        opacity: 0.7,
        pulsePhase: 0.5,
      );

      final modified = original.copyWith(
        intensity: 0.5,
        opacity: 0.3,
        pulsePhase: 0.8,
      );

      expect(modified.id, equals('red_dot_1'));
      expect(modified.cellId, equals('cell_1'));
      expect(modified.intensity, equals(0.5));
      expect(modified.opacity, equals(0.3));
      expect(modified.pulsePhase, equals(0.8));
      // Unchanged properties
      expect(modified.originalLat, equals(25.0330));
      expect(modified.size, equals(10.0));
    });

    test('equality works correctly', () {
      const redDot1 = RedDot(
        id: 'red_dot_1',
        cellId: 'cell_1',
        originalLat: 25.0330,
        originalLng: 121.5654,
        displayLat: 25.0331,
        displayLng: 121.5655,
        intensity: 0.8,
        size: 10.0,
        opacity: 0.7,
        pulsePhase: 0.5,
      );
      const redDot2 = RedDot(
        id: 'red_dot_1',
        cellId: 'cell_1',
        originalLat: 25.0330,
        originalLng: 121.5654,
        displayLat: 25.0331,
        displayLng: 121.5655,
        intensity: 0.8,
        size: 10.0,
        opacity: 0.7,
        pulsePhase: 0.5,
      );
      const redDot3 = RedDot(
        id: 'red_dot_2',
        cellId: 'cell_1',
        originalLat: 25.0330,
        originalLng: 121.5654,
        displayLat: 25.0331,
        displayLng: 121.5655,
        intensity: 0.8,
        size: 10.0,
        opacity: 0.7,
        pulsePhase: 0.5,
      );

      expect(redDot1, equals(redDot2));
      expect(redDot1, isNot(equals(redDot3)));
    });
  });

  group('ViewportBounds', () {
    test('creates with required properties', () {
      const bounds = ViewportBounds(
        north: 25.034,
        south: 25.032,
        east: 121.567,
        west: 121.564,
        zoom: 16.0,
      );

      expect(bounds.north, equals(25.034));
      expect(bounds.south, equals(25.032));
      expect(bounds.east, equals(121.567));
      expect(bounds.west, equals(121.564));
      expect(bounds.zoom, equals(16.0));
    });

    test('contains returns true for point inside', () {
      const bounds = ViewportBounds(
        north: 25.034,
        south: 25.032,
        east: 121.567,
        west: 121.564,
        zoom: 16.0,
      );

      expect(bounds.contains(25.033, 121.565), isTrue);
    });

    test('contains returns false for point outside', () {
      const bounds = ViewportBounds(
        north: 25.034,
        south: 25.032,
        east: 121.567,
        west: 121.564,
        zoom: 16.0,
      );

      // North of bounds
      expect(bounds.contains(25.040, 121.565), isFalse);
      // South of bounds
      expect(bounds.contains(25.030, 121.565), isFalse);
      // East of bounds
      expect(bounds.contains(25.033, 121.570), isFalse);
      // West of bounds
      expect(bounds.contains(25.033, 121.560), isFalse);
    });

    test('contains returns true for point on boundary', () {
      const bounds = ViewportBounds(
        north: 25.034,
        south: 25.032,
        east: 121.567,
        west: 121.564,
        zoom: 16.0,
      );

      expect(bounds.contains(25.034, 121.565), isTrue); // north edge
      expect(bounds.contains(25.032, 121.565), isTrue); // south edge
      expect(bounds.contains(25.033, 121.567), isTrue); // east edge
      expect(bounds.contains(25.033, 121.564), isTrue); // west edge
    });

    test('copyWith creates modified copy', () {
      const original = ViewportBounds(
        north: 25.034,
        south: 25.032,
        east: 121.567,
        west: 121.564,
        zoom: 16.0,
      );

      final modified = original.copyWith(
        north: 25.040,
        zoom: 18.0,
      );

      expect(modified.north, equals(25.040));
      expect(modified.south, equals(25.032));
      expect(modified.zoom, equals(18.0));
    });

    test('equality works correctly', () {
      const bounds1 = ViewportBounds(
        north: 25.034,
        south: 25.032,
        east: 121.567,
        west: 121.564,
        zoom: 16.0,
      );
      const bounds2 = ViewportBounds(
        north: 25.034,
        south: 25.032,
        east: 121.567,
        west: 121.564,
        zoom: 16.0,
      );
      const bounds3 = ViewportBounds(
        north: 25.040,
        south: 25.032,
        east: 121.567,
        west: 121.564,
        zoom: 16.0,
      );

      expect(bounds1, equals(bounds2));
      expect(bounds1, isNot(equals(bounds3)));
    });
  });
}
