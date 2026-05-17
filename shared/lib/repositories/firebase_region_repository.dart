import '../models/parking_region.dart';
import 'firebase_repository_exception.dart';
import 'region_repository.dart';

class FirebaseRegionRepository implements RegionRepository {
  const FirebaseRegionRepository();

  Never _missingConfig() {
    throw const FirebaseRepositoryException(
      'FirebaseRegionRepository needs cloud_firestore wiring. Query /regions/region_sit_tumkur.',
    );
  }

  @override
  Future<ParkingRegion> getMainRegion() async => _missingConfig();

  @override
  Stream<ParkingRegion> watchMainRegion() => _missingConfig();

  @override
  Future<void> upsertRegion(ParkingRegion region) async => _missingConfig();
}
