import '../models/parking_location.dart';
import '../models/geo_point.dart';
import '../utils/geometry_utils.dart';

class ParkingAreaConflictException implements Exception {
  const ParkingAreaConflictException(this.conflict);

  final ParkingAreaConflict conflict;

  String get message => conflict.message;

  @override
  String toString() => message;
}

class ParkingAreaConflictService {
  const ParkingAreaConflictService();

  static const requiredGateMessage =
      'At least one gate is required for a parking area.';
  static const gateInsideAreaMessage =
      'Gates must be inside the parking area polygon.';
  static const duplicateGateMessage = 'Duplicate gates are not allowed.';

  String? validateGateRequirements(ParkingLocation area) {
    if (area.boundaryPoints.length < 3) {
      return null;
    }
    if (area.gatePoints.isEmpty) {
      return requiredGateMessage;
    }
    final seen = <String>{};
    for (final gate in area.gatePoints) {
      final gatePoint = GeoPointValue(
        latitude: gate.latitude,
        longitude: gate.longitude,
      );
      if (!GeometryUtils.pointInPolygon(gatePoint, area.boundaryPoints)) {
        return gateInsideAreaMessage;
      }
      final key =
          '${gate.latitude.toStringAsFixed(7)},${gate.longitude.toStringAsFixed(7)}';
      if (!seen.add(key)) {
        return duplicateGateMessage;
      }
    }
    return null;
  }

  ParkingAreaConflict? validateNoAreaConflict({
    required ParkingLocation candidateArea,
    required Iterable<ParkingLocation> existingAreas,
  }) {
    return GeometryUtils.validateAreaDoesNotConflict(
      candidateArea,
      existingAreas,
    );
  }

  void throwIfConflicting({
    required ParkingLocation candidateArea,
    required Iterable<ParkingLocation> existingAreas,
  }) {
    final conflict = validateNoAreaConflict(
      candidateArea: candidateArea,
      existingAreas: existingAreas,
    );
    if (conflict != null) {
      throw ParkingAreaConflictException(conflict);
    }
  }
}
