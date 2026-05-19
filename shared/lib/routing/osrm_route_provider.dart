import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'route_cache.dart';
import 'route_provider.dart';

class OsrmRouteProvider implements RoutingService {
  OsrmRouteProvider({
    http.Client? client,
    RouteProvider? fallback,
    RouteCache? cache,
    Uri? endpoint,
    this.requestTimeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       _fallback = fallback,
       _cache = cache ?? RouteCache(),
       _endpoint = endpoint ?? Uri.parse('https://router.project-osrm.org');

  final http.Client _client;
  final RouteProvider? _fallback;
  final RouteCache _cache;
  final Uri _endpoint;
  final Duration requestTimeout;

  @override
  Future<RouteOption> getRoute({
    required RoutePoint origin,
    required RoutePoint destination,
    RouteProfile profile = RouteProfile.driving,
  }) async {
    final routes = await findRoutes(
      origin: origin,
      destination: destination,
      profile: profile,
    );
    if (routes.isEmpty) {
      throw const RoutingException('No route was found.');
    }
    return routes.first;
  }

  @override
  Future<List<RouteOption>> getAlternativeRoutes({
    required RoutePoint origin,
    required RoutePoint destination,
    RouteProfile profile = RouteProfile.driving,
  }) {
    return findRoutes(
      origin: origin,
      destination: destination,
      profile: profile,
    );
  }

  @override
  Future<double> getEstimatedDistance({
    required RoutePoint origin,
    required RoutePoint destination,
    RouteProfile profile = RouteProfile.driving,
  }) async {
    return (await getRoute(
      origin: origin,
      destination: destination,
      profile: profile,
    )).distanceKm;
  }

  @override
  Future<int> getEstimatedTime({
    required RoutePoint origin,
    required RoutePoint destination,
    RouteProfile profile = RouteProfile.driving,
  }) async {
    return (await getRoute(
      origin: origin,
      destination: destination,
      profile: profile,
    )).durationMinutes;
  }

  @override
  Future<List<RouteOption>> findRoutes({
    required RoutePoint origin,
    required RoutePoint destination,
    RouteProfile profile = RouteProfile.driving,
  }) async {
    final cached = _cache.get(
      origin: origin,
      destination: destination,
      profile: profile,
    );
    if (cached != null) {
      return cached;
    }

    try {
      final routes = await _fetchRoadRoutes(
        origin: origin,
        destination: destination,
        profile: profile,
      );
      _cache.put(
        origin: origin,
        destination: destination,
        profile: profile,
        routes: routes,
      );
      return routes;
    } on Object catch (error) {
      final fallback = _fallback;
      if (fallback == null) {
        throw RoutingException(
          'Road routing is unavailable. Please check internet access or routing provider quota.',
          cause: error,
        );
      }
      final routes = await fallback.findRoutes(
        origin: origin,
        destination: destination,
        profile: profile,
      );
      if (routes.isEmpty) {
        throw RoutingException('No fallback route was found.', cause: error);
      }
      return routes;
    }
  }

  Future<List<RouteOption>> _fetchRoadRoutes({
    required RoutePoint origin,
    required RoutePoint destination,
    required RouteProfile profile,
  }) async {
    final coordinates =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final request = _endpoint.replace(
      path: '/route/v1/${profile.osrmProfile}/$coordinates',
      queryParameters: const {
        'alternatives': 'true',
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'true',
      },
    );
    final response = await _client.get(request).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw RoutingException(
        'OSRM route request failed with HTTP ${response.statusCode}.',
      );
    }
    final body = jsonDecode(response.body) as Map<String, Object?>;
    final code = body['code'];
    if (code != 'Ok') {
      throw RoutingException(
        body['message'] as String? ?? 'OSRM returned $code.',
      );
    }
    return parseOsrmRouteResponse(
      body,
      destinationLabel: destination.label,
      provider: 'osrm',
    );
  }
}

List<RouteOption> parseOsrmRouteResponse(
  Map<String, Object?> body, {
  String provider = 'osrm',
  String? destinationLabel,
}) {
  final routesJson = body['routes'];
  if (routesJson is! List || routesJson.isEmpty) {
    throw const RoutingException('OSRM response did not include routes.');
  }

  return [
    for (var index = 0; index < routesJson.length; index++)
      _routeFromJson(
        routesJson[index] as Map<String, Object?>,
        index: index,
        provider: provider,
        destinationLabel: destinationLabel,
      ),
  ];
}

RouteOption _routeFromJson(
  Map<String, Object?> route, {
  required int index,
  required String provider,
  required String? destinationLabel,
}) {
  final geometry = route['geometry'];
  if (geometry is! Map<String, Object?>) {
    throw const RoutingException('OSRM route is missing GeoJSON geometry.');
  }
  final coordinates = geometry['coordinates'];
  if (coordinates is! List || coordinates.isEmpty) {
    throw const RoutingException('OSRM route geometry has no coordinates.');
  }
  final points = <RoutePoint>[];
  for (final coordinate in coordinates) {
    if (coordinate is! List || coordinate.length < 2) {
      continue;
    }
    points.add(
      RoutePoint(
        id: 'osrm_${index}_${points.length}',
        label: index == 0 ? 'Best road route' : 'Alternative road route',
        latitude: (coordinate[1] as num).toDouble(),
        longitude: (coordinate[0] as num).toDouble(),
      ),
    );
  }
  if (points.length < 2) {
    throw const RoutingException('OSRM route geometry is too short.');
  }
  final meters = (route['distance'] as num?)?.toDouble() ?? 0;
  final seconds = (route['duration'] as num?)?.toDouble() ?? 0;
  return RouteOption(
    id: index == 0 ? 'osrm_best' : 'osrm_alt_$index',
    name: index == 0 ? 'Fastest road route' : 'Alternative road route $index',
    points: points,
    distanceKm: _round(meters / 1000, digits: 2),
    durationMinutes: max(1, (seconds / 60).round()),
    isBest: index == 0,
    provider: provider,
    destinationLabel: destinationLabel,
  );
}

double _round(double value, {required int digits}) {
  final factor = pow(10, digits).toDouble();
  return (value * factor).round() / factor;
}
