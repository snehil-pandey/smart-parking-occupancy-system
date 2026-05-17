import '../models/parking_region.dart';
import '../utils/demo_seed.dart';
import 'region_repository.dart';

class InMemoryRegionRepository implements RegionRepository {
  InMemoryRegionRepository({ParkingRegion? seed})
    : _region = seed ?? DemoSeed.sitTumkurRegion();

  ParkingRegion _region;

  @override
  Future<ParkingRegion> getMainRegion() async => _region;

  @override
  Stream<ParkingRegion> watchMainRegion() => Stream.value(_region);

  @override
  Future<void> upsertRegion(ParkingRegion region) async {
    _region = region;
  }
}
