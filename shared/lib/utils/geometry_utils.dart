import '../models/gate_point.dart';
import '../models/geo_point.dart';
import '../models/parking_location.dart';
import '../models/parking_region.dart';

class GeometryBounds {
  const GeometryBounds({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;

  bool overlaps(
    GeometryBounds other, {
    double epsilon = GeometryUtils.epsilon,
  }) {
    return minLatitude <= other.maxLatitude + epsilon &&
        maxLatitude + epsilon >= other.minLatitude &&
        minLongitude <= other.maxLongitude + epsilon &&
        maxLongitude + epsilon >= other.minLongitude;
  }
}

class ParkingAreaConflict {
  const ParkingAreaConflict({
    required this.message,
    this.areaId,
    this.areaName,
    this.isInvalidCandidate = false,
  });

  factory ParkingAreaConflict.withArea(ParkingLocation area) {
    return ParkingAreaConflict(
      areaId: area.id,
      areaName: area.name,
      message:
          'Parking area conflicts with an existing parking zone: ${area.name}',
    );
  }

  factory ParkingAreaConflict.invalid(String message) {
    return ParkingAreaConflict(message: message, isInvalidCandidate: true);
  }

  final String message;
  final String? areaId;
  final String? areaName;
  final bool isInvalidCandidate;
}

class ParkingRegionConflict {
  const ParkingRegionConflict({
    required this.message,
    this.regionId,
    this.regionName,
    this.isInvalidCandidate = false,
  });

  factory ParkingRegionConflict.withRegion(ParkingRegion region) {
    return ParkingRegionConflict(
      regionId: region.regionId,
      regionName: region.name,
      message: 'Your region overlaps with existing region: ${region.name}',
    );
  }

  factory ParkingRegionConflict.invalid(String message) {
    return ParkingRegionConflict(message: message, isInvalidCandidate: true);
  }

  final String message;
  final String? regionId;
  final String? regionName;
  final bool isInvalidCandidate;
}

class GeometryUtils {
  const GeometryUtils._();

  static const double epsilon = 0.000000001;

  static bool pointInPolygon(GeoPointValue point, List<GeoPointValue> polygon) {
    final openPolygon = _openPolygon(polygon);
    if (openPolygon.length < 3) {
      return false;
    }
    if (_pointOnBoundary(point, openPolygon)) {
      return true;
    }

    var inside = false;
    for (
      var i = 0, j = openPolygon.length - 1;
      i < openPolygon.length;
      j = i++
    ) {
      final pi = openPolygon[i];
      final pj = openPolygon[j];
      final intersects =
          ((pi.latitude > point.latitude) != (pj.latitude > point.latitude)) &&
          (point.longitude <
              (pj.longitude - pi.longitude) *
                      (point.latitude - pi.latitude) /
                      (pj.latitude - pi.latitude) +
                  pi.longitude);
      if (intersects) {
        inside = !inside;
      }
    }
    return inside;
  }

  static bool polygonInsidePolygon(
    List<GeoPointValue> innerPolygon,
    List<GeoPointValue> outerPolygon,
  ) {
    final inner = _openPolygon(innerPolygon);
    final outer = _openPolygon(outerPolygon);
    if (inner.length < 3 || outer.length < 3) {
      return false;
    }
    if (!inner.every((point) => pointInPolygon(point, outer))) {
      return false;
    }
    for (var i = 0; i < inner.length; i++) {
      final innerA = inner[i];
      final innerB = inner[(i + 1) % inner.length];
      for (var j = 0; j < outer.length; j++) {
        final outerA = outer[j];
        final outerB = outer[(j + 1) % outer.length];
        if (_segmentsProperlyIntersect(innerA, innerB, outerA, outerB)) {
          return false;
        }
      }
    }
    return true;
  }

  static bool gateInsideRegion(
    GatePoint gate,
    List<GeoPointValue> regionPolygon,
  ) {
    return pointInPolygon(
      GeoPointValue(latitude: gate.latitude, longitude: gate.longitude),
      regionPolygon,
    );
  }

  static bool lineSegmentsIntersect(
    GeoPointValue a1,
    GeoPointValue a2,
    GeoPointValue b1,
    GeoPointValue b2,
  ) {
    final o1 = _orientation(a1, a2, b1);
    final o2 = _orientation(a1, a2, b2);
    final o3 = _orientation(b1, b2, a1);
    final o4 = _orientation(b1, b2, a2);

    if (o1.abs() <= epsilon && _pointOnSegment(b1, a1, a2)) {
      return true;
    }
    if (o2.abs() <= epsilon && _pointOnSegment(b2, a1, a2)) {
      return true;
    }
    if (o3.abs() <= epsilon && _pointOnSegment(a1, b1, b2)) {
      return true;
    }
    if (o4.abs() <= epsilon && _pointOnSegment(a2, b1, b2)) {
      return true;
    }

    return (o1 > epsilon && o2 < -epsilon || o1 < -epsilon && o2 > epsilon) &&
        (o3 > epsilon && o4 < -epsilon || o3 < -epsilon && o4 > epsilon);
  }

  static bool polygonsIntersect(
    List<GeoPointValue> polyA,
    List<GeoPointValue> polyB,
  ) {
    final a = _openPolygon(polyA);
    final b = _openPolygon(polyB);
    if (a.length < 3 || b.length < 3) {
      return false;
    }
    if (!calculateBounds(a).overlaps(calculateBounds(b))) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      final a1 = a[i];
      final a2 = a[(i + 1) % a.length];
      for (var j = 0; j < b.length; j++) {
        final b1 = b[j];
        final b2 = b[(j + 1) % b.length];
        if (lineSegmentsIntersect(a1, a2, b1, b2)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool polygonContainsPolygon(
    List<GeoPointValue> outer,
    List<GeoPointValue> inner,
  ) {
    final outerOpen = _openPolygon(outer);
    final innerOpen = _openPolygon(inner);
    if (outerOpen.length < 3 || innerOpen.length < 3) {
      return false;
    }
    if (!calculateBounds(outerOpen).overlaps(calculateBounds(innerOpen))) {
      return false;
    }
    return innerOpen.every((point) => pointInPolygon(point, outerOpen));
  }

  static bool polygonsOverlapOrTouch(
    List<GeoPointValue> polyA,
    List<GeoPointValue> polyB,
  ) {
    final a = _openPolygon(polyA);
    final b = _openPolygon(polyB);
    if (a.length < 3 || b.length < 3) {
      return false;
    }
    if (!calculateBounds(a).overlaps(calculateBounds(b))) {
      return false;
    }
    return polygonsIntersect(a, b) ||
        polygonContainsPolygon(a, b) ||
        polygonContainsPolygon(b, a) ||
        pointInPolygon(a.first, b) ||
        pointInPolygon(b.first, a);
  }

  static ParkingAreaConflict? validateAreaDoesNotConflict(
    ParkingLocation candidateArea,
    Iterable<ParkingLocation> existingAreas,
  ) {
    if (_openPolygon(candidateArea.boundaryPoints).length < 3) {
      return ParkingAreaConflict.invalid(
        'Parking area polygon must have at least 3 points.',
      );
    }
    final candidateBounds = calculateBounds(candidateArea.boundaryPoints);
    for (final area in existingAreas) {
      if (area.id == candidateArea.id) {
        continue;
      }
      if (_openPolygon(area.boundaryPoints).length < 3) {
        continue;
      }
      final existingBounds = calculateBounds(area.boundaryPoints);
      if (!candidateBounds.overlaps(existingBounds)) {
        continue;
      }
      if (polygonsOverlapOrTouch(
        candidateArea.boundaryPoints,
        area.boundaryPoints,
      )) {
        return ParkingAreaConflict.withArea(area);
      }
    }
    return null;
  }

  static ParkingRegionConflict? validateRegionDoesNotConflict(
    ParkingRegion candidateRegion,
    Iterable<ParkingRegion> existingRegions,
  ) {
    if (_openPolygon(candidateRegion.boundaryPoints).length < 3) {
      return ParkingRegionConflict.invalid(
        'Region polygon must have at least 3 points.',
      );
    }
    final candidateBounds = calculateBounds(candidateRegion.boundaryPoints);
    for (final region in existingRegions) {
      if (region.regionId == candidateRegion.regionId) {
        continue;
      }
      if (_openPolygon(region.boundaryPoints).length < 3) {
        continue;
      }
      final existingBounds = calculateBounds(region.boundaryPoints);
      if (!candidateBounds.overlaps(existingBounds)) {
        continue;
      }
      if (polygonsOverlapOrTouch(
        candidateRegion.boundaryPoints,
        region.boundaryPoints,
      )) {
        return ParkingRegionConflict.withRegion(region);
      }
    }
    return null;
  }

  static GeoPointValue calculatePolygonCenter(List<GeoPointValue> points) {
    final openPoints = _openPolygon(points);
    if (openPoints.isEmpty) {
      return const GeoPointValue(latitude: 0, longitude: 0);
    }

    var signedArea = 0.0;
    var latitudeSum = 0.0;
    var longitudeSum = 0.0;
    for (var i = 0; i < openPoints.length; i++) {
      final current = openPoints[i];
      final next = openPoints[(i + 1) % openPoints.length];
      final cross =
          current.longitude * next.latitude - next.longitude * current.latitude;
      signedArea += cross;
      longitudeSum += (current.longitude + next.longitude) * cross;
      latitudeSum += (current.latitude + next.latitude) * cross;
    }

    signedArea *= 0.5;
    if (signedArea.abs() < 0.000000000001) {
      final latitude =
          openPoints.map((point) => point.latitude).reduce((a, b) => a + b) /
          openPoints.length;
      final longitude =
          openPoints.map((point) => point.longitude).reduce((a, b) => a + b) /
          openPoints.length;
      return GeoPointValue(latitude: latitude, longitude: longitude);
    }

    return GeoPointValue(
      latitude: latitudeSum / (6 * signedArea),
      longitude: longitudeSum / (6 * signedArea),
    );
  }

  static GeometryBounds calculateBounds(List<GeoPointValue> points) {
    final openPoints = _openPolygon(points);
    if (openPoints.isEmpty) {
      return const GeometryBounds(
        minLatitude: 0,
        maxLatitude: 0,
        minLongitude: 0,
        maxLongitude: 0,
      );
    }

    return GeometryBounds(
      minLatitude: openPoints
          .map((point) => point.latitude)
          .reduce((a, b) => a < b ? a : b),
      maxLatitude: openPoints
          .map((point) => point.latitude)
          .reduce((a, b) => a > b ? a : b),
      minLongitude: openPoints
          .map((point) => point.longitude)
          .reduce((a, b) => a < b ? a : b),
      maxLongitude: openPoints
          .map((point) => point.longitude)
          .reduce((a, b) => a > b ? a : b),
    );
  }

  static bool _pointOnBoundary(
    GeoPointValue point,
    List<GeoPointValue> polygon,
  ) {
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      if (_pointOnSegment(point, a, b)) {
        return true;
      }
    }
    return false;
  }

  static bool _pointOnSegment(
    GeoPointValue point,
    GeoPointValue a,
    GeoPointValue b,
  ) {
    final cross =
        (point.latitude - a.latitude) * (b.longitude - a.longitude) -
        (point.longitude - a.longitude) * (b.latitude - a.latitude);
    if (cross.abs() > epsilon) {
      return false;
    }
    final withinLatitude =
        point.latitude >= _min(a.latitude, b.latitude) - epsilon &&
        point.latitude <= _max(a.latitude, b.latitude) + epsilon;
    final withinLongitude =
        point.longitude >= _min(a.longitude, b.longitude) - epsilon &&
        point.longitude <= _max(a.longitude, b.longitude) + epsilon;
    return withinLatitude && withinLongitude;
  }

  static bool _segmentsProperlyIntersect(
    GeoPointValue a,
    GeoPointValue b,
    GeoPointValue c,
    GeoPointValue d,
  ) {
    final o1 = _orientation(a, b, c);
    final o2 = _orientation(a, b, d);
    final o3 = _orientation(c, d, a);
    final o4 = _orientation(c, d, b);
    return o1 * o2 < 0 && o3 * o4 < 0;
  }

  static List<GeoPointValue> _openPolygon(List<GeoPointValue> polygon) {
    if (polygon.length < 2) {
      return polygon;
    }
    final first = polygon.first;
    final last = polygon.last;
    if ((first.latitude - last.latitude).abs() <= epsilon &&
        (first.longitude - last.longitude).abs() <= epsilon) {
      return polygon.sublist(0, polygon.length - 1);
    }
    return polygon;
  }

  static double _orientation(
    GeoPointValue a,
    GeoPointValue b,
    GeoPointValue c,
  ) {
    return (b.longitude - a.longitude) * (c.latitude - a.latitude) -
        (b.latitude - a.latitude) * (c.longitude - a.longitude);
  }

  static double _min(double a, double b) => a < b ? a : b;

  static double _max(double a, double b) => a > b ? a : b;
}
