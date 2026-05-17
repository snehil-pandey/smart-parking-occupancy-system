import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/parking_location.dart';
import '../routing/dijkstra_route_engine.dart';
import '../routing/route_provider.dart';
import '../services/qr_payload_service.dart';

class DemoSeed {
  static final now = DateTime.now();

  static final parkingLocations = <ParkingLocation>[
    ParkingLocation(
      id: 'loc_metro_park',
      adminId: 'admin_demo_001',
      name: 'Metro Park Hub',
      address: 'MG Road, Bengaluru',
      latitude: 12.9757,
      longitude: 77.6052,
      totalSpaces: 80,
      availableSpaces: 18,
      pricePerHour: 60,
      vehicleTypes: const [VehicleType.car, VehicleType.bike, VehicleType.ev],
      imageUrls: const [
        'https://images.unsplash.com/photo-1506521781263-d8422e82f27a',
      ],
      isOpen: true,
      openingTime: '06:00',
      closingTime: '23:00',
      createdAt: now.subtract(const Duration(days: 20)),
      updatedAt: now,
    ),
    ParkingLocation(
      id: 'loc_cubbon_square',
      adminId: 'admin_demo_001',
      name: 'Cubbon Square Parking',
      address: 'Kasturba Road, Bengaluru',
      latitude: 12.9763,
      longitude: 77.5929,
      totalSpaces: 54,
      availableSpaces: 9,
      pricePerHour: 75,
      vehicleTypes: const [VehicleType.car, VehicleType.van],
      imageUrls: const [
        'https://images.unsplash.com/photo-1590674899484-d5640e854abe',
      ],
      isOpen: true,
      openingTime: '07:00',
      closingTime: '22:30',
      createdAt: now.subtract(const Duration(days: 15)),
      updatedAt: now,
    ),
    ParkingLocation(
      id: 'loc_lakeview_ev',
      adminId: 'admin_demo_001',
      name: 'Lakeview EV Parking',
      address: 'Ulsoor Lake Road, Bengaluru',
      latitude: 12.9815,
      longitude: 77.6192,
      totalSpaces: 42,
      availableSpaces: 14,
      pricePerHour: 90,
      vehicleTypes: const [VehicleType.car, VehicleType.ev],
      imageUrls: const [
        'https://images.unsplash.com/photo-1573348722427-f1d6819fdf98',
      ],
      isOpen: true,
      openingTime: '05:30',
      closingTime: '23:30',
      createdAt: now.subtract(const Duration(days: 8)),
      updatedAt: now,
    ),
  ];

  static List<Booking> bookings() {
    final qr = const QrPayloadService();
    final start = now.subtract(const Duration(hours: 1));
    final end = start.add(const Duration(hours: 3));
    final payload = qr.buildPayload(
      bookingId: 'book_demo_001',
      userId: 'user_demo_001',
      parkingLocationId: 'loc_metro_park',
      vehicleNumber: 'KA 05 MN 4242',
      startTime: start,
      endTime: end,
    );
    return [
      Booking(
        id: 'book_demo_001',
        userId: 'user_demo_001',
        adminId: 'admin_demo_001',
        parkingLocationId: 'loc_metro_park',
        vehicleNumber: 'KA 05 MN 4242',
        startTime: start,
        endTime: end,
        price: 180,
        status: BookingStatus.active,
        qrPayload: payload,
        createdAt: start,
        updatedAt: now,
      ),
    ];
  }

  static DijkstraRouteEngine routeEngine() {
    final nodes = <String, RoutePoint>{
      'mg_road': const RoutePoint(
        id: 'mg_road',
        label: 'MG Road',
        latitude: 12.9757,
        longitude: 77.6052,
      ),
      'cubbon': const RoutePoint(
        id: 'cubbon',
        label: 'Cubbon Park',
        latitude: 12.9763,
        longitude: 77.5929,
      ),
      'ulsoor': const RoutePoint(
        id: 'ulsoor',
        label: 'Ulsoor',
        latitude: 12.9815,
        longitude: 77.6192,
      ),
      'brigade': const RoutePoint(
        id: 'brigade',
        label: 'Brigade Road',
        latitude: 12.9719,
        longitude: 77.6077,
      ),
    };
    return DijkstraRouteEngine(
      nodes: nodes,
      edges: const {
        'mg_road': [GraphEdge('cubbon', 1.7), GraphEdge('brigade', 0.8)],
        'cubbon': [GraphEdge('mg_road', 1.7), GraphEdge('brigade', 2.1)],
        'brigade': [GraphEdge('mg_road', 0.8), GraphEdge('ulsoor', 1.9)],
        'ulsoor': [GraphEdge('brigade', 1.9), GraphEdge('mg_road', 2.4)],
      },
    );
  }
}
