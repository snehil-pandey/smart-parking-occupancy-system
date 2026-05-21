import 'package:flutter_test/flutter_test.dart';
import 'package:park_here_shared/park_here_shared.dart';

void main() {
  test('parking price validation accepts free parking', () {
    expect(ParkingLocation.isValidPrice(0), isTrue);
    expect(ParkingLocation.isValidPrice(100), isTrue);
  });

  test('vehicle type parser handles legacy aliases safely', () {
    expect(parseVehicleType('twoWheeler'), VehicleType.bike);
    expect(parseVehicleType('fourWheeler'), VehicleType.car);
    expect(parseVehicleType('motorcycle'), VehicleType.bike);
    expect(parseVehicleType('scooter'), VehicleType.bike);
  });

  test('vehicle type parser handles unknown values safely', () {
    expect(parseVehicleType('hoverboard'), VehicleType.car);
  });

  test('user profile maps from Firestore seed fields', () {
    final user = AppUser.fromJson({
      'userId': 'auth_user_001',
      'authUid': 'auth_user_001',
      'email': 'ananya@parkhere.demo',
      'name': 'Ananya R',
      'phone': '+91 90000 20001',
      'vehicleNumber': 'KA 06 AB 1201',
      'defaultVehicleType': 'twoWheeler',
      'role': 'user',
    });

    expect(user.id, 'auth_user_001');
    expect(user.defaultVehicleType, VehicleType.bike);
  });

  test('admin profile maps from Firestore seed fields', () {
    final admin = AdminProfile.fromJson({
      'adminId': 'admin_sit_parking_office',
      'authUid': 'admin_sit_parking_office',
      'email': 'admin@parkhere.demo',
      'businessName': 'SIT Tumkur Parking Office',
      'ownerName': 'Campus Parking Administrator',
      'phone': '+91 90000 10001',
      'role': 'admin',
    });

    expect(admin.id, 'admin_sit_parking_office');
    expect(admin.businessName, 'SIT Tumkur Parking Office');
  });

  test('parking price validation rejects negative and over-maximum prices', () {
    expect(ParkingLocation.isValidPrice(-1), isFalse);
    expect(ParkingLocation.isValidPrice(101), isFalse);
    expect(
      () => ParkingLocation.validatePrice(101),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('pointInPolygon includes interior and boundary points', () {
    expect(
      GeometryUtils.pointInPolygon(
        const GeoPointValue(latitude: 1, longitude: 1),
        _squareRegion,
      ),
      isTrue,
    );
    expect(
      GeometryUtils.pointInPolygon(
        const GeoPointValue(latitude: 0, longitude: 1),
        _squareRegion,
      ),
      isTrue,
    );
    expect(
      GeometryUtils.pointInPolygon(
        const GeoPointValue(latitude: 3, longitude: 1),
        _squareRegion,
      ),
      isFalse,
    );
  });

  test('polygonInsidePolygon rejects parking polygons outside region', () {
    expect(
      GeometryUtils.polygonInsidePolygon(const [
        GeoPointValue(latitude: 0.2, longitude: 0.2),
        GeoPointValue(latitude: 0.8, longitude: 0.2),
        GeoPointValue(latitude: 0.8, longitude: 0.8),
      ], _squareRegion),
      isTrue,
    );
    expect(
      GeometryUtils.polygonInsidePolygon(const [
        GeoPointValue(latitude: 0.2, longitude: 0.2),
        GeoPointValue(latitude: 2.4, longitude: 0.2),
        GeoPointValue(latitude: 0.8, longitude: 0.8),
      ], _squareRegion),
      isFalse,
    );
  });

  test('gateInsideRegion rejects gates outside controlled region', () {
    final now = DateTime.now();
    expect(
      GeometryUtils.gateInsideRegion(
        GatePoint(
          gateId: 'gate_inside',
          name: 'Inside',
          latitude: 1,
          longitude: 1,
          type: GatePointType.entry,
          createdAt: now,
        ),
        _squareRegion,
      ),
      isTrue,
    );
    expect(
      GeometryUtils.gateInsideRegion(
        GatePoint(
          gateId: 'gate_outside',
          name: 'Outside',
          latitude: 3,
          longitude: 1,
          type: GatePointType.entry,
          createdAt: now,
        ),
        _squareRegion,
      ),
      isFalse,
    );
  });

  test('calculatePolygonCenter and calculateBounds use polygon points', () {
    final center = GeometryUtils.calculatePolygonCenter(_squareRegion);
    final bounds = GeometryUtils.calculateBounds(_squareRegion);

    expect(center.latitude, closeTo(1, 0.0001));
    expect(center.longitude, closeTo(1, 0.0001));
    expect(bounds.minLatitude, 0);
    expect(bounds.maxLatitude, 2);
    expect(bounds.minLongitude, 0);
    expect(bounds.maxLongitude, 2);
  });

  test('separate parking polygons are allowed', () {
    final candidate = _boxArea(
      id: 'candidate',
      name: 'Candidate',
      points: _box(0, 0, 1, 1),
    );
    final existing = _boxArea(
      id: 'existing',
      name: 'Existing',
      points: _box(2, 2, 3, 3),
    );

    expect(
      GeometryUtils.validateAreaDoesNotConflict(candidate, [existing]),
      isNull,
    );
  });

  test('overlapping parking polygons are rejected with area name', () {
    final candidate = _boxArea(
      id: 'candidate',
      name: 'Candidate',
      points: _box(0, 0, 2, 2),
    );
    final existing = _boxArea(
      id: 'existing',
      name: 'Library Lot',
      points: _box(1, 1, 3, 3),
    );

    final conflict = GeometryUtils.validateAreaDoesNotConflict(candidate, [
      existing,
    ]);

    expect(conflict, isNotNull);
    expect(conflict!.areaName, 'Library Lot');
    expect(conflict.message, contains('Library Lot'));
  });

  test('crossing polygon edges are rejected', () {
    final candidate = _boxArea(
      id: 'candidate',
      name: 'Candidate',
      points: const [
        GeoPointValue(latitude: 0, longitude: 0.8),
        GeoPointValue(latitude: 2, longitude: 0.8),
        GeoPointValue(latitude: 2, longitude: 1.2),
        GeoPointValue(latitude: 0, longitude: 1.2),
      ],
    );
    final existing = _boxArea(
      id: 'existing',
      name: 'Existing',
      points: _box(0.8, 0, 1.2, 2),
    );

    expect(
      GeometryUtils.validateAreaDoesNotConflict(candidate, [existing]),
      isNotNull,
    );
  });

  test('one parking polygon inside another is rejected', () {
    final candidate = _boxArea(
      id: 'candidate',
      name: 'Candidate',
      points: _box(1, 1, 2, 2),
    );
    final existing = _boxArea(
      id: 'existing',
      name: 'Existing',
      points: _box(0, 0, 3, 3),
    );

    expect(
      GeometryUtils.validateAreaDoesNotConflict(candidate, [existing]),
      isNotNull,
    );
  });

  test('same parking area id is ignored while editing', () {
    final candidate = _boxArea(
      id: 'same',
      name: 'Edited',
      points: _box(0, 0, 2, 2),
    );
    final existing = _boxArea(
      id: 'same',
      name: 'Saved',
      points: _box(0, 0, 2, 2),
    );

    expect(
      GeometryUtils.validateAreaDoesNotConflict(candidate, [existing]),
      isNull,
    );
  });

  test('touching parking boundaries are rejected', () {
    final candidate = _boxArea(
      id: 'candidate',
      name: 'Candidate',
      points: _box(0, 0, 1, 1),
    );
    final existing = _boxArea(
      id: 'existing',
      name: 'Existing',
      points: _box(1, 0, 2, 1),
    );

    expect(
      GeometryUtils.validateAreaDoesNotConflict(candidate, [existing]),
      isNotNull,
    );
  });

  test('invalid parking polygon is rejected', () {
    final candidate = _boxArea(
      id: 'candidate',
      name: 'Candidate',
      points: const [
        GeoPointValue(latitude: 0, longitude: 0),
        GeoPointValue(latitude: 1, longitude: 1),
      ],
    );

    final conflict = GeometryUtils.validateAreaDoesNotConflict(candidate, []);

    expect(conflict, isNotNull);
    expect(conflict!.isInvalidCandidate, isTrue);
  });

  test('repository save rejects overlapping parking polygons', () async {
    final existing = _boxArea(
      id: 'existing',
      name: 'Library Lot',
      points: _box(0, 0, 2, 2),
    );
    final candidate = _boxArea(
      id: 'candidate',
      name: 'Candidate',
      points: _box(1, 1, 3, 3),
    );
    final repository = InMemoryParkingRepository(seed: [existing]);

    expect(
      () => repository.upsert(candidate),
      throwsA(isA<ParkingAreaConflictException>()),
    );
  });

  test('overlapping regions are rejected with public region name', () {
    final candidate = _boxRegion(
      id: 'candidate',
      name: 'New Region',
      points: _box(0, 0, 2, 2),
    );
    final existing = _boxRegion(
      id: 'existing',
      name: 'North Campus',
      points: _box(1, 1, 3, 3),
    );

    final conflict = GeometryUtils.validateRegionDoesNotConflict(candidate, [
      existing,
    ]);

    expect(conflict, isNotNull);
    expect(conflict!.regionName, 'North Campus');
    expect(conflict.message, contains('North Campus'));
  });

  test('same region id is ignored while editing', () {
    final candidate = _boxRegion(
      id: 'same_region',
      name: 'Edited Region',
      points: _box(0, 0, 2, 2),
    );
    final existing = _boxRegion(
      id: 'same_region',
      name: 'Saved Region',
      points: _box(0, 0, 2, 2),
    );

    expect(
      GeometryUtils.validateRegionDoesNotConflict(candidate, [existing]),
      isNull,
    );
  });

  test('full area cannot be reserved', () async {
    final repository = InMemoryParkingRepository(
      seed: [_area(availableSpaces: 0)],
    );

    expect(
      () => repository.reserveSlot('area_test'),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'cancellation fine is Rs. 10 only when hourly price is above Rs. 10',
    () async {
      final now = DateTime.now();
      final premium = InMemoryBookingRepository(
        seed: [_booking(id: 'book_premium', price: 30, now: now)],
      );
      final freeOrLow = InMemoryBookingRepository(
        seed: [_booking(id: 'book_low', price: 10, now: now)],
      );

      final premiumCancelled = await premium.cancelBooking(
        bookingId: 'book_premium',
      );
      final lowCancelled = await freeOrLow.cancelBooking(bookingId: 'book_low');

      expect(premiumCancelled.cancellationFine, 10);
      expect(lowCancelled.cancellationFine, 0);
      expect(premiumCancelled.status, BookingStatus.cancelled);
      expect(premiumCancelled.cancelledAt, isNotNull);
    },
  );

  test('cancellation releases slot once', () async {
    final now = DateTime.now();
    final parking = InMemoryParkingRepository(
      seed: [_area(availableSpaces: 4)],
    );
    final bookings = InMemoryBookingRepository(
      parkingRepository: parking,
      seed: [_booking(id: 'book_cancel_once', price: 20, now: now)],
    );

    await bookings.cancelBooking(bookingId: 'book_cancel_once');
    await bookings.cancelBooking(bookingId: 'book_cancel_once');

    final area = await parking.findById('area_test');
    expect(area!.availableSpaces, 5);
  });

  test('gatePoints serialize and deserialize', () {
    final now = DateTime.now();
    final area = _area(
      gatePoints: [
        GatePoint(
          gateId: 'gate_test',
          name: 'Main Gate',
          latitude: 13.3281,
          longitude: 77.1257,
          type: GatePointType.both,
          createdAt: now,
        ),
      ],
    );

    final restored = ParkingLocation.fromJson(area.toJson());

    expect(restored.gatePoints, hasLength(1));
    expect(restored.gatePoints.first.name, 'Main Gate');
    expect(restored.gatePoints.first.type, GatePointType.both);
  });
}

const _squareRegion = [
  GeoPointValue(latitude: 0, longitude: 0),
  GeoPointValue(latitude: 0, longitude: 2),
  GeoPointValue(latitude: 2, longitude: 2),
  GeoPointValue(latitude: 2, longitude: 0),
];

List<GeoPointValue> _box(
  double minLat,
  double minLng,
  double maxLat,
  double maxLng,
) {
  return [
    GeoPointValue(latitude: minLat, longitude: minLng),
    GeoPointValue(latitude: minLat, longitude: maxLng),
    GeoPointValue(latitude: maxLat, longitude: maxLng),
    GeoPointValue(latitude: maxLat, longitude: minLng),
  ];
}

ParkingLocation _boxArea({
  required String id,
  required String name,
  required List<GeoPointValue> points,
  String adminId = 'admin_test',
}) {
  final now = DateTime.now();
  final center = points.length >= 3
      ? GeometryUtils.calculatePolygonCenter(points)
      : const GeoPointValue(latitude: 0, longitude: 0);
  return ParkingLocation(
    id: id,
    regionId: 'region_test',
    adminId: adminId,
    name: name,
    address: 'Test',
    boundaryPoints: points,
    gatePoints: const [],
    latitude: center.latitude,
    longitude: center.longitude,
    totalSpaces: 10,
    availableSpaces: 10,
    pricePerHour: 10,
    vehicleTypes: const [VehicleType.car],
    thumbnailRefs: const [],
    imagePreviewRefs: const [],
    isOpen: true,
    openingTime: '06:00',
    closingTime: '22:00',
    createdAt: now,
    updatedAt: now,
  );
}

ParkingRegion _boxRegion({
  required String id,
  required String name,
  required List<GeoPointValue> points,
}) {
  final now = DateTime.now();
  final center = GeometryUtils.calculatePolygonCenter(points);
  return ParkingRegion(
    regionId: id,
    name: name,
    address: 'Test',
    boundaryPoints: points,
    centerLat: center.latitude,
    centerLng: center.longitude,
    createdByAdminId: 'admin_$id',
    createdAt: now,
    updatedAt: now,
  );
}

ParkingLocation _area({
  int availableSpaces = 3,
  double pricePerHour = 20,
  List<GatePoint> gatePoints = const [],
}) {
  final now = DateTime.now();
  return ParkingLocation(
    id: 'area_test',
    adminId: 'admin_test',
    name: 'Test Area',
    address: 'SIT Tumkur',
    boundaryPoints: const [
      GeoPointValue(latitude: 13.3281, longitude: 77.1251),
      GeoPointValue(latitude: 13.3282, longitude: 77.1259),
      GeoPointValue(latitude: 13.3276, longitude: 77.1259),
    ],
    gatePoints: gatePoints,
    latitude: 13.3281,
    longitude: 77.1257,
    totalSpaces: 5,
    availableSpaces: availableSpaces,
    pricePerHour: pricePerHour,
    vehicleTypes: const [VehicleType.car],
    thumbnailRefs: const [],
    imagePreviewRefs: const [],
    isOpen: true,
    openingTime: '06:00',
    closingTime: '22:00',
    createdAt: now,
    updatedAt: now,
  );
}

Booking _booking({
  required String id,
  required double price,
  required DateTime now,
}) {
  return Booking(
    id: id,
    userId: 'user_test',
    adminId: 'admin_test',
    parkingLocationId: 'area_test',
    qrId: 'qr_$id',
    vehicleNumber: 'KA 06 TEST',
    startTime: now,
    endTime: now.add(const Duration(hours: 1)),
    price: price,
    status: BookingStatus.active,
    qrPayload: '{}',
    createdAt: now,
    updatedAt: now,
  );
}
