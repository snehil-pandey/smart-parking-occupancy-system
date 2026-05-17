import '../models/parking_region.dart';

abstract interface class RegionRepository {
  Future<ParkingRegion> getMainRegion();

  Stream<ParkingRegion> watchMainRegion();

  Future<void> upsertRegion(ParkingRegion region);
}
