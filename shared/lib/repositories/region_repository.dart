import '../models/parking_region.dart';

abstract interface class RegionRepository {
  Future<ParkingRegion> getMainRegion();

  Stream<ParkingRegion> watchMainRegion();

  Future<ParkingRegion?> getControlledRegion(String adminId);

  Stream<ParkingRegion?> watchControlledRegion(String adminId);

  Future<List<ParkingRegion>> getAllRegions();

  Stream<List<ParkingRegion>> watchAllRegions();

  Future<void> upsertRegion(ParkingRegion region);
}
