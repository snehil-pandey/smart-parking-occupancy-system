import '../models/gate_point.dart';
import '../models/geo_point.dart';

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
}

class GeometryUtils {
  const GeometryUtils._();

  static bool pointInPolygon(GeoPointValue point, List<GeoPointValue> polygon) {
    if (polygon.length < 3) {
      return false;
    }
    if (_pointOnBoundary(point, polygon)) {
      return true;
    }

    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final pi = polygon[i];
      final pj = polygon[j];
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
    if (innerPolygon.length < 3 || outerPolygon.length < 3) {
      return false;
    }
    if (!innerPolygon.every((point) => pointInPolygon(point, outerPolygon))) {
      return false;
    }
    for (var i = 0; i < innerPolygon.length; i++) {
      final innerA = innerPolygon[i];
      final innerB = innerPolygon[(i + 1) % innerPolygon.length];
      for (var j = 0; j < outerPolygon.length; j++) {
        final outerA = outerPolygon[j];
        final outerB = outerPolygon[(j + 1) % outerPolygon.length];
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

  static GeoPointValue calculatePolygonCenter(List<GeoPointValue> points) {
    if (points.isEmpty) {
      return const GeoPointValue(latitude: 0, longitude: 0);
    }

    var signedArea = 0.0;
    var latitudeSum = 0.0;
    var longitudeSum = 0.0;
    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];
      final cross =
          current.longitude * next.latitude - next.longitude * current.latitude;
      signedArea += cross;
      longitudeSum += (current.longitude + next.longitude) * cross;
      latitudeSum += (current.latitude + next.latitude) * cross;
    }

    signedArea *= 0.5;
    if (signedArea.abs() < 0.000000000001) {
      final latitude =
          points.map((point) => point.latitude).reduce((a, b) => a + b) /
          points.length;
      final longitude =
          points.map((point) => point.longitude).reduce((a, b) => a + b) /
          points.length;
      return GeoPointValue(latitude: latitude, longitude: longitude);
    }

    return GeoPointValue(
      latitude: latitudeSum / (6 * signedArea),
      longitude: longitudeSum / (6 * signedArea),
    );
  }

  static GeometryBounds calculateBounds(List<GeoPointValue> points) {
    if (points.isEmpty) {
      return const GeometryBounds(
        minLatitude: 0,
        maxLatitude: 0,
        minLongitude: 0,
        maxLongitude: 0,
      );
    }

    return GeometryBounds(
      minLatitude: points
          .map((point) => point.latitude)
          .reduce((a, b) => a < b ? a : b),
      maxLatitude: points
          .map((point) => point.latitude)
          .reduce((a, b) => a > b ? a : b),
      minLongitude: points
          .map((point) => point.longitude)
          .reduce((a, b) => a < b ? a : b),
      maxLongitude: points
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
    const tolerance = 0.000000001;
    final cross =
        (point.latitude - a.latitude) * (b.longitude - a.longitude) -
        (point.longitude - a.longitude) * (b.latitude - a.latitude);
    if (cross.abs() > tolerance) {
      return false;
    }
    final withinLatitude =
        point.latitude >= _min(a.latitude, b.latitude) - tolerance &&
        point.latitude <= _max(a.latitude, b.latitude) + tolerance;
    final withinLongitude =
        point.longitude >= _min(a.longitude, b.longitude) - tolerance &&
        point.longitude <= _max(a.longitude, b.longitude) + tolerance;
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
