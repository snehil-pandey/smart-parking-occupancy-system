class RoutePoint {
  const RoutePoint({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String label;
  final double latitude;
  final double longitude;
}

class RouteOption {
  const RouteOption({
    required this.id,
    required this.name,
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    required this.isBest,
  });

  final String id;
  final String name;
  final List<RoutePoint> points;
  final double distanceKm;
  final int durationMinutes;
  final bool isBest;
}

abstract interface class RouteProvider {
  Future<List<RouteOption>> findRoutes({
    required RoutePoint origin,
    required RoutePoint destination,
  });
}
