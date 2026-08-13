import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Geofencing & Distance Calculation Tests', () {
    // Haversine formula calculation for test assertions
    double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
      const p = 0.017453292519943295; // Math.PI / 180
      final a = 0.5 -
          cos((lat2 - lat1) * p) / 2 +
          cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
      return 12742000 * asin(sqrt(a)); // 2 * R; R = 6371000 m
    }

    bool isWithinRadius({
      required double teacherLat,
      required double teacherLon,
      required double studentLat,
      required double studentLon,
      required double radiusMeters,
    }) {
      final distance = calculateDistance(teacherLat, teacherLon, studentLat, studentLon);
      return distance <= radiusMeters;
    }

    test('Zero distance when coordinates match exactly', () {
      const lat = 30.3545;
      const lon = 76.3688;
      final distance = calculateDistance(lat, lon, lat, lon);

      expect(distance, closeTo(0.0, 0.001));
      expect(isWithinRadius(
        teacherLat: lat,
        teacherLon: lon,
        studentLat: lat,
        studentLon: lon,
        radiusMeters: 50,
      ), isTrue);
    });

    test('Student within 50m radius is accepted', () {
      const teacherLat = 30.35450;
      const teacherLon = 76.36880;
      // ~20 meters offset
      const studentLat = 30.35465;
      const studentLon = 76.36885;

      final distance = calculateDistance(teacherLat, teacherLon, studentLat, studentLon);
      expect(distance, lessThan(50.0));
      expect(isWithinRadius(
        teacherLat: teacherLat,
        teacherLon: teacherLon,
        studentLat: studentLat,
        studentLon: studentLon,
        radiusMeters: 50.0,
      ), isTrue);
    });

    test('Student outside allowed radius is rejected', () {
      const teacherLat = 30.35450;
      const teacherLon = 76.36880;
      // ~500 meters offset
      const studentLat = 30.35900;
      const studentLon = 76.36880;

      final distance = calculateDistance(teacherLat, teacherLon, studentLat, studentLon);
      expect(distance, greaterThan(50.0));
      expect(isWithinRadius(
        teacherLat: teacherLat,
        teacherLon: teacherLon,
        studentLat: studentLat,
        studentLon: studentLon,
        radiusMeters: 50.0,
      ), isFalse);
    });
  });
}
