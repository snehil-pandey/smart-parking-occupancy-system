import '../models/parking_location.dart';
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
