import 'dart:math';

import 'route_provider.dart';

class StraightLineRouteProvider implements RouteProvider {
  const StraightLineRouteProvider();

  @override
  Future<List<RouteOption>> findRoutes({
    required RoutePoint origin,
    required RoutePoint destination,
  }) async {
    final distance = _distanceKm(origin, destination);
    final duration = max(3, (distance / 22 * 60).round());
    return [
      RouteOption(
        id: 'gps_direct',
        name: 'GPS direct',
        points: [origin, destination],
        distanceKm: double.parse(distance.toStringAsFixed(1)),
        durationMinutes: duration,
        isBest: true,
      ),
      RouteOption(
        id: 'campus_inner',
        name: 'Campus inner road',
        points: [
          origin,
          RoutePoint(
            id: 'campus_mid',
            label: 'Campus connector',
            latitude: (origin.latitude + destination.latitude) / 2,
            longitude: (origin.longitude + destination.longitude) / 2,
          ),
          destination,
        ],
        distanceKm: double.parse((distance * 1.18).toStringAsFixed(1)),
        durationMinutes: max(duration + 2, (duration * 1.2).round()),
        isBest: false,
      ),
    ];
  }

  double _distanceKm(RoutePoint origin, RoutePoint destination) {
    const earthRadiusKm = 6371.0;
    final dLat = _radians(destination.latitude - origin.latitude);
    final dLon = _radians(destination.longitude - origin.longitude);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_radians(origin.latitude)) *
            cos(_radians(destination.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _radians(double degrees) => degrees * pi / 180;
}
