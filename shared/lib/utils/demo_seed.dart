import 'dart:convert';

import 'package:image/image.dart' as img;

import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/parking_area_image.dart';
import '../models/parking_location.dart';
import '../models/parking_region.dart';
import '../models/parking_review.dart';
import '../models/issue_report.dart';
import '../models/geo_point.dart';
import '../routing/dijkstra_route_engine.dart';
import '../routing/route_provider.dart';
import '../services/qr_payload_service.dart';

class DemoSeed {
  static final now = DateTime.now();

  static const sitRegionId = 'region_sit_tumkur';

  static List<GeoPointValue> sitTumkurBoundary() => const [
    GeoPointValue(latitude: 13.3524, longitude: 77.0995),
    GeoPointValue(latitude: 13.3528, longitude: 77.1044),
    GeoPointValue(latitude: 13.3481, longitude: 77.1050),
    GeoPointValue(latitude: 13.3477, longitude: 77.1001),
  ];

  static ParkingRegion sitTumkurRegion() => ParkingRegion(
    regionId: sitRegionId,
    name: 'SIT Tumkur',
    address: 'Siddaganga Institute of Technology, Tumakuru, Karnataka',
    boundaryPoints: sitTumkurBoundary(),
    centerLat: 13.3503,
    centerLng: 77.1022,
    createdByAdminId: 'admin_demo_001',
    createdAt: now.subtract(const Duration(days: 45)),
    updatedAt: now,
  );

  static final parkingLocations = <ParkingLocation>[
    ParkingLocation(
      id: 'loc_metro_park',
      regionId: sitRegionId,
      adminId: 'admin_demo_001',
      name: 'SIT Main Gate Parking',
      description: 'Closest area for visitors entering from B.H. Road.',
      address: 'SIT Main Gate, Tumakuru',
      boundaryPoints: const [
        GeoPointValue(latitude: 13.3509, longitude: 77.1010),
        GeoPointValue(latitude: 13.3513, longitude: 77.1018),
        GeoPointValue(latitude: 13.3505, longitude: 77.1021),
        GeoPointValue(latitude: 13.3502, longitude: 77.1012),
      ],
      latitude: 13.3508,
      longitude: 77.1015,
      totalSpaces: 80,
      availableSpaces: 18,
      pricePerHour: 60,
      vehicleTypes: const [VehicleType.car, VehicleType.bike, VehicleType.ev],
      thumbnailRefs: const ['img_metro_001'],
      imagePreviewRefs: const ['img_metro_001'],
      isOpen: true,
      openingTime: '06:00',
      closingTime: '23:00',
      createdAt: now.subtract(const Duration(days: 20)),
      updatedAt: now,
      ratingAverage: 4.4,
      ratingCount: 18,
    ),
    ParkingLocation(
      id: 'loc_cubbon_square',
      regionId: sitRegionId,
      adminId: 'admin_demo_001',
      name: 'Mechanical Block Parking',
      description: 'Wide two-wheeler and car area near workshop buildings.',
      address: 'Mechanical Block, SIT Tumkur',
      boundaryPoints: const [
        GeoPointValue(latitude: 13.3495, longitude: 77.1027),
        GeoPointValue(latitude: 13.3498, longitude: 77.1037),
        GeoPointValue(latitude: 13.3489, longitude: 77.1038),
        GeoPointValue(latitude: 13.3486, longitude: 77.1029),
      ],
      latitude: 13.3492,
      longitude: 77.1032,
      totalSpaces: 54,
      availableSpaces: 9,
      pricePerHour: 75,
      vehicleTypes: const [VehicleType.car, VehicleType.van],
      thumbnailRefs: const ['img_cubbon_001'],
      imagePreviewRefs: const ['img_cubbon_001'],
      isOpen: true,
      openingTime: '07:00',
      closingTime: '22:30',
      createdAt: now.subtract(const Duration(days: 15)),
      updatedAt: now,
      ratingAverage: 4.1,
      ratingCount: 11,
    ),
    ParkingLocation(
      id: 'loc_lakeview_ev',
      regionId: sitRegionId,
      adminId: 'admin_demo_001',
      name: 'Library EV Parking',
      description:
          'Quieter parking stretch near library and EV charging point.',
      address: 'Central Library, SIT Tumkur',
      boundaryPoints: const [
        GeoPointValue(latitude: 13.3516, longitude: 77.1031),
        GeoPointValue(latitude: 13.3519, longitude: 77.1040),
        GeoPointValue(latitude: 13.3511, longitude: 77.1042),
        GeoPointValue(latitude: 13.3508, longitude: 77.1033),
      ],
      latitude: 13.3514,
      longitude: 77.1036,
      totalSpaces: 42,
      availableSpaces: 14,
      pricePerHour: 90,
      vehicleTypes: const [VehicleType.car, VehicleType.ev],
      thumbnailRefs: const ['img_lakeview_001'],
      imagePreviewRefs: const ['img_lakeview_001'],
      isOpen: true,
      openingTime: '05:30',
      closingTime: '23:30',
      createdAt: now.subtract(const Duration(days: 8)),
      updatedAt: now,
      ratingAverage: 4.7,
      ratingCount: 9,
    ),
    ParkingLocation(
      id: 'loc_sit_auditorium',
      regionId: sitRegionId,
      adminId: 'admin_demo_001',
      name: 'Auditorium Parking',
      description: 'Best for events and seminar hall access.',
      address: 'Auditorium, SIT Tumkur',
      boundaryPoints: const [
        GeoPointValue(latitude: 13.3488, longitude: 77.1006),
        GeoPointValue(latitude: 13.3491, longitude: 77.1015),
        GeoPointValue(latitude: 13.3482, longitude: 77.1016),
        GeoPointValue(latitude: 13.3479, longitude: 77.1008),
      ],
      latitude: 13.3485,
      longitude: 77.1011,
      totalSpaces: 64,
      availableSpaces: 22,
      pricePerHour: 45,
      vehicleTypes: const [VehicleType.car, VehicleType.bike],
      thumbnailRefs: const ['img_auditorium_001'],
      imagePreviewRefs: const ['img_auditorium_001'],
      isOpen: true,
      openingTime: '06:00',
      closingTime: '22:00',
      createdAt: now.subtract(const Duration(days: 4)),
      updatedAt: now,
      ratingAverage: 3.9,
      ratingCount: 6,
    ),
  ];

  static List<ParkingAreaImage> parkingAreaImages() {
    return [
      _image(
        imageId: 'img_metro_001',
        areaId: 'loc_metro_park',
        color: img.ColorRgb8(255, 201, 40),
      ),
      _image(
        imageId: 'img_cubbon_001',
        areaId: 'loc_cubbon_square',
        color: img.ColorRgb8(49, 92, 114),
      ),
      _image(
        imageId: 'img_lakeview_001',
        areaId: 'loc_lakeview_ev',
        color: img.ColorRgb8(138, 198, 164),
      ),
      _image(
        imageId: 'img_auditorium_001',
        areaId: 'loc_sit_auditorium',
        color: img.ColorRgb8(183, 95, 72),
      ),
    ];
  }

  static List<ParkingReview> reviews() => [
    ParkingReview(
      reviewId: 'review_demo_001',
      userId: 'user_demo_001',
      areaId: 'loc_metro_park',
      rating: 5,
      comment: 'Fast entry near the main gate.',
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(days: 1)),
    ),
    ParkingReview(
      reviewId: 'review_demo_002',
      userId: 'user_demo_002',
      areaId: 'loc_cubbon_square',
      rating: 4,
      comment: 'Good space, but fills up during lab hours.',
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
  ];

  static List<IssueReport> issues() => [
    IssueReport(
      issueId: 'issue_demo_001',
      userId: 'user_demo_003',
      areaId: 'loc_metro_park',
      adminId: 'admin_demo_001',
      type: 'blocked_slot',
      message: 'Two slots near the exit are blocked by cones.',
      status: IssueStatus.open,
      createdAt: now.subtract(const Duration(hours: 4)),
      updatedAt: now.subtract(const Duration(hours: 4)),
    ),
    IssueReport(
      issueId: 'issue_demo_002',
      userId: 'user_demo_004',
      areaId: 'loc_lakeview_ev',
      adminId: 'admin_demo_001',
      type: 'lighting',
      message: 'The EV area is dim after 7 PM.',
      status: IssueStatus.inProgress,
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(hours: 3)),
    ),
  ];

  static ParkingAreaImage _image({
    required String imageId,
    required String areaId,
    required img.Color color,
  }) {
    final thumbnail = _encodedPlaceholder(96, 64, color);
    final preview = _encodedPlaceholder(360, 220, color);
    return ParkingAreaImage(
      imageId: imageId,
      areaId: areaId,
      uploadedByAdminId: 'admin_demo_001',
      thumbnailBase64: thumbnail,
      previewBase64: preview,
      mimeType: 'image/jpeg',
      uploadedAt: now.subtract(const Duration(days: 2)),
    );
  }

  static String _encodedPlaceholder(int width, int height, img.Color color) {
    final canvas = img.Image(width: width, height: height);
    img.fill(canvas, color: img.ColorRgb8(246, 248, 247));
    img.fillRect(
      canvas,
      x1: 8,
      y1: 8,
      x2: width - 8,
      y2: height - 8,
      color: color,
    );
    img.fillRect(
      canvas,
      x1: 16,
      y1: height ~/ 2,
      x2: width - 16,
      y2: height ~/ 2 + 6,
      color: img.ColorRgb8(20, 20, 20),
    );
    return base64Encode(img.encodeJpg(canvas, quality: 70));
  }

  static List<int> demoUploadBytes() {
    final canvas = img.Image(width: 900, height: 560);
    img.fill(canvas, color: img.ColorRgb8(238, 241, 235));
    img.fillRect(
      canvas,
      x1: 40,
      y1: 40,
      x2: 860,
      y2: 520,
      color: img.ColorRgb8(255, 201, 40),
    );
    for (var y = 110; y < 500; y += 90) {
      img.fillRect(
        canvas,
        x1: 70,
        y1: y,
        x2: 830,
        y2: y + 8,
        color: img.ColorRgb8(20, 20, 20),
      );
    }
    return img.encodeJpg(canvas, quality: 88);
  }

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
