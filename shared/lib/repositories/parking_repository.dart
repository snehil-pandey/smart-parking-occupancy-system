import '../models/parking_location.dart';

abstract interface class ParkingRepository {
  Future<List<ParkingLocation>> watchNearby({
    required double latitude,
    required double longitude,
  });

  Future<List<ParkingLocation>> getOpenAreas({int limit = 100});

  Stream<List<ParkingLocation>> watchOpenAreas({int limit = 100});

  Future<List<ParkingLocation>> getByAdmin(String adminId);

  Stream<List<ParkingLocation>> watchByAdmin(String adminId, {int limit = 50});

  Future<List<ParkingLocation>> getAllAreas({int limit = 500});

  Stream<List<ParkingLocation>> watchAllAreas({int limit = 500});

  Future<List<ParkingLocation>> getByRegion(String regionId, {int limit = 30});

  Stream<List<ParkingLocation>> watchByRegion(
    String regionId, {
    int limit = 30,
  });

  Future<ParkingLocation?> findById(String id);

  Future<void> upsert(ParkingLocation location);

  Future<ParkingLocation> reserveSlot(String areaId);

  Future<ParkingLocation> releaseSlot(String areaId);

  Future<void> updateAvailability({
    required String locationId,
    required int totalSpaces,
    required int availableSpaces,
    required bool isOpen,
    required double pricePerHour,
  });
}
