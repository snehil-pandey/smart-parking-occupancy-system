import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:park_here_shared/park_here_shared.dart';

void main() {
  test('OSRM parser maps GeoJSON road geometry into route options', () {
    final routes = parseOsrmRouteResponse({
      'code': 'Ok',
      'routes': [
        {
          'distance': 1234.0,
          'duration': 360.0,
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [77.125, 13.329],
              [77.126, 13.328],
              [77.127, 13.327],
            ],
          },
        },
      ],
    }, destinationLabel: 'Main Gate');

    expect(routes, hasLength(1));
    expect(routes.first.provider, 'osrm');
    expect(routes.first.distanceKm, 1.23);
    expect(routes.first.durationMinutes, 6);
    expect(routes.first.destinationLabel, 'Main Gate');
    expect(routes.first.points[1].latitude, 13.328);
    expect(routes.first.points[1].longitude, 77.126);
  });

  test('polyline codec decodes Google precision-5 route geometry', () {
    final points = const PolylineCodec().decode('_p~iF~ps|U_ulLnnqC_mqNvxq`@');

    expect(points, hasLength(3));
    expect(points.first.latitude, closeTo(38.5, 0.00001));
    expect(points.first.longitude, closeTo(-120.2, 0.00001));
    expect(points.last.latitude, closeTo(43.252, 0.00001));
    expect(points.last.longitude, closeTo(-126.453, 0.00001));
  });

  test(
    'route cache reuses responses for rounded origin destination profile',
    () {
      final cache = RouteCache();
      final origin = const RoutePoint(
        id: 'origin',
        label: 'Origin',
        latitude: 13.3281211,
        longitude: 77.1256930,
      );
      final destination = const RoutePoint(
        id: 'gate',
        label: 'Gate',
        latitude: 13.32916,
        longitude: 77.12502,
      );
      final routes = [
        RouteOption(
          id: 'route',
          name: 'Route',
          points: [origin, destination],
          distanceKm: 0.2,
          durationMinutes: 1,
          isBest: true,
        ),
      ];

      cache.put(
        origin: origin,
        destination: destination,
        profile: RouteProfile.driving,
        routes: routes,
      );

      expect(
        cache.get(
          origin: origin,
          destination: destination,
          profile: RouteProfile.driving,
        ),
        same(routes),
      );
    },
  );

  test('gate selector prefers nearest entry or both gate', () {
    final now = DateTime.now();
    final location = _area(
      gatePoints: [
        GatePoint(
          gateId: 'exit',
          name: 'Exit Gate',
          latitude: 13.326,
          longitude: 77.126,
          type: GatePointType.exit,
          createdAt: now,
        ),
        GatePoint(
          gateId: 'main',
          name: 'Main Gate',
          latitude: 13.328,
          longitude: 77.125,
          type: GatePointType.both,
          createdAt: now,
        ),
      ],
    );

    final destination = const ParkingGateSelector().destinationFor(
      origin: const RoutePoint(
        id: 'origin',
        label: 'Origin',
        latitude: 13.329,
        longitude: 77.125,
      ),
      location: location,
    );

    expect(destination.id, 'main');
    expect(destination.label, 'Main Gate');
  });

  test('OSRM provider falls back to local road graph when API fails', () async {
    final provider = OsrmRouteProvider(
      client: MockClient(
        (_) async => http.Response('service unavailable', 503),
      ),
      fallback: SitTumkurRoadGraphRouteProvider(),
    );

    final routes = await provider.findRoutes(
      origin: const RoutePoint(
        id: 'origin',
        label: 'Origin',
        latitude: 13.32916,
        longitude: 77.12502,
      ),
      destination: const RoutePoint(
        id: 'destination',
        label: 'Destination',
        latitude: 13.32737,
        longitude: 77.12582,
      ),
    );

    expect(routes.first.provider, 'local-road-graph');
    expect(routes.first.isFallback, isTrue);
    expect(routes.first.points.length, greaterThan(2));
  });

  test('OSRM provider returns alternative road routes when supplied', () async {
    final provider = OsrmRouteProvider(
      client: MockClient(
        (_) async => http.Response('''
          {
            "code": "Ok",
            "routes": [
              {
                "distance": 1000,
                "duration": 240,
                "geometry": {"type": "LineString", "coordinates": [[77.1,13.1],[77.2,13.2]]}
              },
              {
                "distance": 1200,
                "duration": 300,
                "geometry": {"type": "LineString", "coordinates": [[77.1,13.1],[77.15,13.15],[77.2,13.2]]}
              }
            ]
          }
          ''', 200),
      ),
    );

    final routes = await provider.findRoutes(
      origin: const RoutePoint(
        id: 'origin',
        label: 'Origin',
        latitude: 13.1,
        longitude: 77.1,
      ),
      destination: const RoutePoint(
        id: 'destination',
        label: 'Destination',
        latitude: 13.2,
        longitude: 77.2,
      ),
    );

    expect(routes, hasLength(2));
    expect(routes.first.isBest, isTrue);
    expect(routes.last.isBest, isFalse);
  });
}

ParkingLocation _area({List<GatePoint> gatePoints = const []}) {
  final now = DateTime.now();
  return ParkingLocation(
    id: 'area_test',
    adminId: 'admin',
    name: 'Test Area',
    address: 'SIT Tumkur',
    boundaryPoints: const [],
    gatePoints: gatePoints,
    latitude: 13.327,
    longitude: 77.125,
    totalSpaces: 10,
    availableSpaces: 5,
    pricePerHour: 20,
    vehicleTypes: const [VehicleType.car],
    thumbnailRefs: const [],
    imagePreviewRefs: const [],
    isOpen: true,
    openingTime: '08:00',
    closingTime: '20:00',
    createdAt: now,
    updatedAt: now,
  );
}
