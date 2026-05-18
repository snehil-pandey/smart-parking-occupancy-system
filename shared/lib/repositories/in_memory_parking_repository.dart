import '../models/parking_location.dart';
import '../utils/demo_seed.dart';
import 'parking_repository.dart';

class InMemoryParkingRepository implements ParkingRepository {
  InMemoryParkingRepository({List<ParkingLocation>? seed})
    : _locations = [...?seed] {
    if (_locations.isEmpty) {
      _locations.addAll(DemoSeed.parkingLocations);
    }
  }

  final List<ParkingLocation> _locations;

  @override
  Future<ParkingLocation?> findById(String id) async {
    return _locations.where((location) => location.id == id).firstOrNull;
  }

  @override
  Future<List<ParkingLocation>> getByAdmin(String adminId) async {
    return _locations.where((location) => location.adminId == adminId).toList();
  }

  @override
  Stream<List<ParkingLocation>> watchByAdmin(String adminId, {int limit = 50}) {
    return Stream.fromFuture(
      getByAdmin(adminId).then((locations) => locations.take(limit).toList()),
    );
  }

  @override
  Future<List<ParkingLocation>> getByRegion(
    String regionId, {
    int limit = 30,
  }) async {
    return _locations
        .where((location) => location.regionId == regionId)
        .take(limit)
        .toList();
  }

  @override
  Stream<List<ParkingLocation>> watchByRegion(
    String regionId, {
    int limit = 30,
  }) {
    return Stream.fromFuture(getByRegion(regionId, limit: limit));
  }

  @override
  Future<List<ParkingLocation>> watchNearby({
    required double latitude,
    required double longitude,
  }) async {
    final copy = [..._locations]
      ..sort((a, b) => b.availableSpaces.compareTo(a.availableSpaces));
    return copy;
  }

  @override
  Future<void> updateAvailability({
    required String locationId,
    required int totalSpaces,
    required int availableSpaces,
    required bool isOpen,
    required double pricePerHour,
  }) async {
    ParkingLocation.validatePrice(pricePerHour);
    final index = _locations.indexWhere(
      (location) => location.id == locationId,
    );
    if (index == -1) {
      return;
    }
    _locations[index] = _locations[index].copyWith(
      totalSpaces: totalSpaces,
      availableSpaces: availableSpaces.clamp(0, totalSpaces),
      isOpen: isOpen,
      pricePerHour: pricePerHour,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> upsert(ParkingLocation location) async {
    ParkingLocation.validatePrice(location.pricePerHour);
    final index = _locations.indexWhere((item) => item.id == location.id);
    if (index == -1) {
      _locations.add(location);
    } else {
      _locations[index] = location;
    }
  }

  @override
  Future<ParkingLocation> reserveSlot(String areaId) async {
    final index = _locations.indexWhere((location) => location.id == areaId);
    if (index == -1) {
      throw StateError('Parking area $areaId was not found.');
    }
    final location = _locations[index];
    if (!location.isOpen || location.availableSpaces < 1) {
      throw StateError('Parking area $areaId has no available slots.');
    }
    final updated = location.copyWith(
      availableSpaces: location.availableSpaces - 1,
      updatedAt: DateTime.now(),
    );
    _locations[index] = updated;
    return updated;
  }

  @override
  Future<ParkingLocation> releaseSlot(String areaId) async {
    final index = _locations.indexWhere((location) => location.id == areaId);
    if (index == -1) {
      throw StateError('Parking area $areaId was not found.');
    }
    final location = _locations[index];
    final updated = location.copyWith(
      availableSpaces: (location.availableSpaces + 1).clamp(
        0,
        location.totalSpaces,
      ),
      updatedAt: DateTime.now(),
    );
    _locations[index] = updated;
    return updated;
  }
}
