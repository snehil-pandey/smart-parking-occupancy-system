import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:park_here_user/main.dart';
import 'package:park_here_user/src/user_app_controller.dart';
import 'package:park_here_shared/park_here_shared.dart';

void main() {
  testWidgets('Park Here user app renders', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(LocalAuthService()),
          parkingRepositoryProvider.overrideWithValue(
            InMemoryParkingRepository(),
          ),
          bookingRepositoryProvider.overrideWithValue(
            InMemoryBookingRepository(),
          ),
          imageRepositoryProvider.overrideWithValue(InMemoryImageRepository()),
          userLocationServiceProvider.overrideWithValue(
            const _TestLocationService(),
          ),
          reviewRepositoryProvider.overrideWithValue(
            InMemoryReviewRepository(),
          ),
          issueRepositoryProvider.overrideWithValue(InMemoryIssueRepository()),
          notificationRepositoryProvider.overrideWithValue(
            _TestNotificationRepository(),
          ),
          routeProvider.overrideWithValue(SitTumkurRoadGraphRouteProvider()),
          firebaseReadinessProvider.overrideWithValue(
            const FirebaseReadiness(
              isConfigured: true,
              message: 'Test Firebase readiness.',
            ),
          ),
        ],
        child: const ParkHereUserApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nearby parking'), findsOneWidget);
  });

  test('Explore nearby available filters out full and closed areas', () {
    final state = UserAppState.signedOut().copyWith(
      position: const UserPosition(
        latitude: 13.3281211,
        longitude: 77.1256930,
        isFallback: false,
        message: 'Test GPS location.',
      ),
      locations: [
        _area(id: 'available_near', availableSpaces: 3, latitude: 13.3282),
        _area(
          id: 'region_sit_tumkur',
          regionId: 'region_sit_tumkur',
          availableSpaces: 10,
          latitude: 13.3281,
        ),
        _area(id: 'full', availableSpaces: 0, latitude: 13.3280),
        _area(
          id: 'closed',
          availableSpaces: 4,
          isOpen: false,
          latitude: 13.3279,
        ),
        _area(id: 'available_far', availableSpaces: 5, latitude: 13.3320),
      ],
    );

    expect(state.nearbyAvailableLocations.map((area) => area.id), [
      'available_near',
      'available_far',
    ]);
  });

  test('single-select parking filters toggle back to all', () {
    expect(
      toggleParkingFilter(ParkingFilter.all, ParkingFilter.free),
      ParkingFilter.free,
    );
    expect(
      toggleParkingFilter(ParkingFilter.free, ParkingFilter.free),
      ParkingFilter.all,
    );
    expect(
      toggleParkingFilter(ParkingFilter.topRated, ParkingFilter.nearest),
      ParkingFilter.nearest,
    );
    expect(
      toggleParkingFilter(ParkingFilter.nearest, ParkingFilter.all),
      ParkingFilter.all,
    );
  });

  test('state treats confirmed and active parking bookings as active', () {
    final now = DateTime.now();
    final confirmed = _booking(
      id: 'book_confirmed',
      now: now,
      status: BookingStatus.confirmed,
    );
    final activeParking = _booking(
      id: 'book_active_parking',
      now: now,
      status: BookingStatus.activeParking,
    );

    expect(
      UserAppState.signedOut().copyWith(bookings: [confirmed]).activeBooking,
      confirmed,
    );
    expect(
      UserAppState.signedOut()
          .copyWith(bookings: [activeParking])
          .activeBooking,
      activeParking,
    );
  });

  test('entry QR is locked before 5 minute unlock window', () {
    final now = DateTime.now();
    final booking = _booking(
      id: 'book_future',
      now: now,
      status: BookingStatus.confirmed,
      startTime: now.add(const Duration(minutes: 15)),
    );
    final ticket = _ticket(booking: booking, now: now);

    expect(booking.canShowEntryQr(ticket, now: now), isFalse);
    expect(
      booking.canShowEntryQr(
        ticket,
        now: booking.startTime.subtract(const Duration(minutes: 5)),
      ),
      isTrue,
    );
  });
}

class _TestLocationService implements UserLocationService {
  const _TestLocationService();

  static const _position = UserPosition(
    latitude: 13.3281211,
    longitude: 77.1256930,
    isFallback: false,
    message: 'Test GPS location.',
  );

  @override
  Future<UserPosition> currentPosition() async => _position;

  @override
  Stream<UserPosition> positionStream() => Stream.value(_position);
}

class _TestNotificationRepository implements NotificationRepository {
  final _controller = StreamController<List<AppNotification>>.broadcast();

  @override
  Future<void> markRead(String notificationId) async {}

  @override
  Future<void> upsert(AppNotification notification) async {
    _controller.add([notification]);
  }

  @override
  Stream<List<AppNotification>> watchForUser(String userId, {int limit = 30}) {
    return _controller.stream;
  }
}

ParkingLocation _area({
  required String id,
  String regionId = 'region_test',
  required int availableSpaces,
  required double latitude,
  bool isOpen = true,
}) {
  final now = DateTime.now();
  return ParkingLocation(
    id: id,
    regionId: regionId,
    adminId: 'admin_test',
    name: id,
    address: 'SIT Tumkur',
    boundaryPoints: const [],
    gatePoints: const [],
    latitude: latitude,
    longitude: 77.1257,
    totalSpaces: 5,
    availableSpaces: availableSpaces,
    pricePerHour: 20,
    vehicleTypes: const [VehicleType.car],
    thumbnailRefs: const [],
    imagePreviewRefs: const [],
    isOpen: isOpen,
    openingTime: '06:00',
    closingTime: '22:00',
    createdAt: now,
    updatedAt: now,
  );
}

Booking _booking({
  required String id,
  required DateTime now,
  required BookingStatus status,
  DateTime? startTime,
}) {
  final qrId = const QrPayloadService().generateQrId();
  final start = startTime ?? now;
  return Booking(
    id: id,
    userId: 'user_test',
    adminId: 'admin_test',
    parkingLocationId: 'area_test',
    qrId: qrId,
    vehicleNumber: 'KA 06 TEST',
    startTime: start,
    endTime: start.add(const Duration(hours: 2)),
    price: 40,
    status: status,
    qrPayload: const QrPayloadService().buildPayload(qrId: qrId),
    createdAt: now,
    updatedAt: now,
  );
}

ActiveQrTicket _ticket({required Booking booking, required DateTime now}) {
  return ActiveQrTicket(
    qrId: booking.qrId!,
    bookingId: booking.id,
    userId: booking.userId,
    adminId: booking.adminId,
    areaId: booking.parkingLocationId,
    status: ActiveQrStatus.active,
    createdAt: now,
    expiresAt: booking.endTime,
    bookingStartAt: booking.startTime,
    bookingEndAt: booking.endTime,
  );
}
