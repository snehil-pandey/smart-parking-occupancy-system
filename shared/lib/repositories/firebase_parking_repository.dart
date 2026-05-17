import '../models/parking_location.dart';
import 'firebase_repository_exception.dart';
import 'parking_repository.dart';

class FirebaseParkingRepository implements ParkingRepository {
  const FirebaseParkingRepository();

  Never _missingConfig() {
    throw const FirebaseRepositoryException(
      'Firebase packages/config are not wired in this local-first build. '
      'Run flutterfire configure, add firebase_core/cloud_firestore/firebase_storage, '
      'then map this repository to FirebaseFirestore.instance.',
    );
  }

  @override
  Future<ParkingLocation?> findById(String id) async => _missingConfig();

  @override
  Future<List<ParkingLocation>> getByAdmin(String adminId) async =>
      _missingConfig();

  @override
  Future<List<ParkingLocation>> getByRegion(
    String regionId, {
    int limit = 30,
  }) async => _missingConfig();

  @override
  Stream<List<ParkingLocation>> watchByRegion(
    String regionId, {
    int limit = 30,
  }) => _missingConfig();

  @override
  Future<List<ParkingLocation>> watchNearby({
    required double latitude,
    required double longitude,
  }) async => _missingConfig();

  @override
  Future<ParkingLocation> reserveSlot(String areaId) async => _missingConfig();

  @override
  Future<void> updateAvailability({
    required String locationId,
    required int totalSpaces,
    required int availableSpaces,
    required bool isOpen,
    required double pricePerHour,
  }) async => _missingConfig();

  @override
  Future<void> upsert(ParkingLocation location) async => _missingConfig();
}
