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
