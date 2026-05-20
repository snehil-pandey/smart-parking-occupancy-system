import '../models/parking_region.dart';
import '../utils/demo_seed.dart';
import 'region_repository.dart';

class InMemoryRegionRepository implements RegionRepository {
  InMemoryRegionRepository({ParkingRegion? seed})
    : _region = seed ?? DemoSeed.sitTumkurRegion();

  InMemoryRegionRepository.empty() : _region = null;

  ParkingRegion? _region;

  @override
  Future<ParkingRegion> getMainRegion() async {
    final region = _region;
    if (region == null) {
      throw StateError('No region exists.');
    }
    return region;
  }

  @override
  Future<ParkingRegion?> getControlledRegion(String adminId) async {
    final region = _region;
    if (region == null || region.createdByAdminId != adminId) {
      return null;
    }
    return region;
  }

  @override
  Stream<ParkingRegion> watchMainRegion() async* {
    yield await getMainRegion();
  }

  @override
  Stream<ParkingRegion?> watchControlledRegion(String adminId) =>
      Stream.value(_region?.createdByAdminId == adminId ? _region : null);

  @override
  Future<void> upsertRegion(ParkingRegion region) async {
    _region = region;
  }
}
