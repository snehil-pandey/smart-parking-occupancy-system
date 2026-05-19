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

enum RouteProfile {
  driving('driving', averageSpeedKmph: 28),
  walking('foot', averageSpeedKmph: 4.5);

  const RouteProfile(this.osrmProfile, {required this.averageSpeedKmph});

  final String osrmProfile;
  final double averageSpeedKmph;
}

class RouteOption {
  const RouteOption({
    required this.id,
    required this.name,
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    required this.isBest,
    this.isFallback = false,
    this.provider = 'unknown',
    this.destinationLabel,
  });

  final String id;
  final String name;
  final List<RoutePoint> points;
  final double distanceKm;
  final int durationMinutes;
  final bool isBest;
  final bool isFallback;
  final String provider;
  final String? destinationLabel;
}

abstract interface class RouteProvider {
  Future<List<RouteOption>> findRoutes({
    required RoutePoint origin,
    required RoutePoint destination,
    RouteProfile profile = RouteProfile.driving,
  });
}

abstract interface class RoutingService extends RouteProvider {
  Future<RouteOption> getRoute({
    required RoutePoint origin,
    required RoutePoint destination,
    RouteProfile profile = RouteProfile.driving,
  });

  Future<List<RouteOption>> getAlternativeRoutes({
    required RoutePoint origin,
    required RoutePoint destination,
    RouteProfile profile = RouteProfile.driving,
  });

  Future<double> getEstimatedDistance({
    required RoutePoint origin,
    required RoutePoint destination,
    RouteProfile profile = RouteProfile.driving,
  });

  Future<int> getEstimatedTime({
    required RoutePoint origin,
    required RoutePoint destination,
    RouteProfile profile = RouteProfile.driving,
  });
}

class RoutingException implements Exception {
  const RoutingException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'RoutingException: $message';
}
