import '../models/parking_location.dart';

class PlaceSearchResult {
  const PlaceSearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    this.parkingAreaId,
    this.isCurrentLocation = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;
  final String? parkingAreaId;
  final bool isCurrentLocation;
}

abstract interface class PlaceSearchService {
  Future<List<PlaceSearchResult>> searchPlaces(String query);

  Future<String> reverseGeocode({
    required double latitude,
    required double longitude,
  });

  Future<List<PlaceSearchResult>> searchParkingAreas({
    required String query,
    required List<ParkingLocation> parkingAreas,
  });
}

class LocalSitTumkurPlaceSearchService implements PlaceSearchService {
  const LocalSitTumkurPlaceSearchService();

  static const _places = [
    PlaceSearchResult(
      id: 'sit_main_gate',
      title: 'SIT Main Gate',
      subtitle: 'Siddaganga Institute of Technology',
      latitude: 13.3280,
      longitude: 77.1236,
    ),
    PlaceSearchResult(
      id: 'sit_admin_block',
      title: 'SIT Admin Block',
      subtitle: 'Campus office area',
      latitude: 13.3285,
      longitude: 77.1250,
    ),
    PlaceSearchResult(
      id: 'sit_library',
      title: 'SIT Library',
      subtitle: 'Central academic zone',
      latitude: 13.3277,
      longitude: 77.1255,
    ),
    PlaceSearchResult(
      id: 'sit_cse_block',
      title: 'CSE / Academic Block',
      subtitle: 'Academic parking nearby',
      latitude: 13.3290,
      longitude: 77.1264,
    ),
    PlaceSearchResult(
      id: 'sit_auditorium',
      title: 'SIT Auditorium',
      subtitle: 'Event and auditorium zone',
      latitude: 13.3269,
      longitude: 77.1261,
    ),
    PlaceSearchResult(
      id: 'sit_hostel_side',
      title: 'Hostel Side',
      subtitle: 'Hostel road parking area',
      latitude: 13.3302,
      longitude: 77.1274,
    ),
    PlaceSearchResult(
      id: 'sit_sports_ground',
      title: 'Sports Ground',
      subtitle: 'Ground-side access',
      latitude: 13.3258,
      longitude: 77.1248,
    ),
  ];

  @override
  Future<List<PlaceSearchResult>> searchPlaces(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const [];
    }
    final results = <PlaceSearchResult>[];
    if ('current location'.contains(normalized) ||
        'my location'.contains(normalized) ||
        'near me'.contains(normalized)) {
      results.add(
        const PlaceSearchResult(
          id: 'current_location',
          title: 'Current location',
          subtitle: 'Use live GPS as origin',
          latitude: 13.3281211,
          longitude: 77.1256930,
          isCurrentLocation: true,
        ),
      );
    }
    results.addAll(
      _places.where((place) {
        final text = '${place.title} ${place.subtitle}'.toLowerCase();
        return text.contains(normalized);
      }),
    );
    return results.take(8).toList();
  }

  @override
  Future<String> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    return 'Near SIT Tumkur (${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)})';
  }

  @override
  Future<List<PlaceSearchResult>> searchParkingAreas({
    required String query,
    required List<ParkingLocation> parkingAreas,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const [];
    }
    return parkingAreas
        .where((area) => area.isUserVisibleParkingArea)
        .where((area) {
          final text = '${area.name} ${area.description} ${area.address}'
              .toLowerCase();
          return text.contains(normalized);
        })
        .map(
          (area) => PlaceSearchResult(
            id: 'area_${area.id}',
            title: area.name,
            subtitle:
                '${area.availabilityLabel} - ${area.pricePerHour == 0 ? 'Free' : 'Rs. ${area.pricePerHour.toStringAsFixed(0)}/hr'}',
            latitude: area.latitude,
            longitude: area.longitude,
            parkingAreaId: area.id,
          ),
        )
        .take(8)
        .toList();
  }
}
