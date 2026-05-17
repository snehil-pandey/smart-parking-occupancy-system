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
    final index = _locations.indexWhere((item) => item.id == location.id);
    if (index == -1) {
      _locations.add(location);
    } else {
      _locations[index] = location;
    }
  }
}
