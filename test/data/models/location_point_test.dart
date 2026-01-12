import 'package:flutter_test/flutter_test.dart';
import 'package:afterstep_fog/data/models/location_point.dart';

void main() {
  group('LocationPoint', () {
    test('creates with required properties', () {
      final point = LocationPoint(
        latitude: 25.0330,
        longitude: 121.5654,
        accuracy: 10,
        timestamp: 1000000,
      );

      expect(point.latitude, equals(25.0330));
      expect(point.longitude, equals(121.5654));
      expect(point.accuracy, equals(10));
      expect(point.timestamp, equals(1000000));
    });

    test('creates with optional properties', () {
      final point = LocationPoint(
        latitude: 25.0330,
        longitude: 121.5654,
        accuracy: 10,
        timestamp: 1000000,
        altitude: 50.0,
        speed: 1.2,
      );

      expect(point.altitude, equals(50.0));
      expect(point.speed, equals(1.2));
    });

    test('serializes to map', () {
      final point = LocationPoint(
        latitude: 25.0330,
        longitude: 121.5654,
        accuracy: 10,
        timestamp: 1000000,
        altitude: 50.0,
        speed: 1.2,
      );

      final map = point.toMap();

      expect(map['latitude'], equals(25.0330));
      expect(map['longitude'], equals(121.5654));
      expect(map['accuracy'], equals(10));
      expect(map['timestamp'], equals(1000000));
      expect(map['altitude'], equals(50.0));
      expect(map['speed'], equals(1.2));
    });

    test('deserializes from map', () {
      final map = {
        'latitude': 25.0330,
        'longitude': 121.5654,
        'accuracy': 10.0,
        'timestamp': 1000000,
        'altitude': 50.0,
        'speed': 1.2,
      };

      final point = LocationPoint.fromMap(map);

      expect(point.latitude, equals(25.0330));
      expect(point.longitude, equals(121.5654));
      expect(point.accuracy, equals(10.0));
      expect(point.timestamp, equals(1000000));
      expect(point.altitude, equals(50.0));
      expect(point.speed, equals(1.2));
    });

    test('copyWith creates modified copy', () {
      final original = LocationPoint(
        latitude: 25.0330,
        longitude: 121.5654,
        accuracy: 10,
        timestamp: 1000000,
      );

      final modified = original.copyWith(
        latitude: 26.0,
        accuracy: 5,
      );

      expect(modified.latitude, equals(26.0));
      expect(modified.longitude, equals(121.5654)); // unchanged
      expect(modified.accuracy, equals(5));
      expect(modified.timestamp, equals(1000000)); // unchanged
    });

    test('equals works correctly', () {
      final point1 = LocationPoint(
        latitude: 25.0330,
        longitude: 121.5654,
        accuracy: 10,
        timestamp: 1000000,
      );

      final point2 = LocationPoint(
        latitude: 25.0330,
        longitude: 121.5654,
        accuracy: 10,
        timestamp: 1000000,
      );

      final point3 = LocationPoint(
        latitude: 26.0,
        longitude: 121.5654,
        accuracy: 10,
        timestamp: 1000000,
      );

      expect(point1, equals(point2));
      expect(point1, isNot(equals(point3)));
    });
  });

  group('ProcessedLocation', () {
    test('creates with required properties', () {
      final point = LocationPoint(
        latitude: 25.0330,
        longitude: 121.5654,
        accuracy: 10,
        timestamp: 1000000,
      );

      final processed = ProcessedLocation(
        point: point,
        calculatedSpeed: 1.2,
        movementState: MovementState.walking,
        isValid: true,
        distanceFromLast: 10.5,
      );

      expect(processed.point, equals(point));
      expect(processed.calculatedSpeed, equals(1.2));
      expect(processed.movementState, equals(MovementState.walking));
      expect(processed.isValid, isTrue);
      expect(processed.distanceFromLast, equals(10.5));
    });

    test('copyWith creates modified copy', () {
      final point = LocationPoint(
        latitude: 25.0330,
        longitude: 121.5654,
        accuracy: 10,
        timestamp: 1000000,
      );

      final original = ProcessedLocation(
        point: point,
        calculatedSpeed: 1.2,
        movementState: MovementState.walking,
        isValid: true,
        distanceFromLast: 10.5,
      );

      final modified = original.copyWith(
        movementState: MovementState.stationary,
        isValid: false,
      );

      expect(modified.movementState, equals(MovementState.stationary));
      expect(modified.isValid, isFalse);
      expect(modified.calculatedSpeed, equals(1.2)); // unchanged
    });
  });

  group('StayEvent', () {
    test('creates with required properties', () {
      final stay = StayEvent(
        centerLat: 25.0330,
        centerLng: 121.5654,
        startTime: 1000000,
        duration: 60,
        radius: 15.0,
      );

      expect(stay.centerLat, equals(25.0330));
      expect(stay.centerLng, equals(121.5654));
      expect(stay.startTime, equals(1000000));
      expect(stay.duration, equals(60));
      expect(stay.radius, equals(15.0));
    });

    test('copyWith creates modified copy', () {
      final original = StayEvent(
        centerLat: 25.0330,
        centerLng: 121.5654,
        startTime: 1000000,
        duration: 60,
        radius: 15.0,
      );

      final modified = original.copyWith(
        duration: 120,
        radius: 30.0,
      );

      expect(modified.duration, equals(120));
      expect(modified.radius, equals(30.0));
      expect(modified.centerLat, equals(25.0330)); // unchanged
    });

    test('equals works correctly', () {
      final stay1 = StayEvent(
        centerLat: 25.0330,
        centerLng: 121.5654,
        startTime: 1000000,
        duration: 60,
        radius: 15.0,
      );

      final stay2 = StayEvent(
        centerLat: 25.0330,
        centerLng: 121.5654,
        startTime: 1000000,
        duration: 60,
        radius: 15.0,
      );

      expect(stay1, equals(stay2));
    });
  });

  group('MovementState', () {
    test('has expected values', () {
      expect(MovementState.values.length, equals(4));
      expect(MovementState.stationary, isNotNull);
      expect(MovementState.walking, isNotNull);
      expect(MovementState.fastWalking, isNotNull);
      expect(MovementState.tooFast, isNotNull);
    });
  });
}
