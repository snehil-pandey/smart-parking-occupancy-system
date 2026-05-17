import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:park_here_shared/park_here_shared.dart';

final authServiceProvider = Provider<AuthService>((ref) => LocalAuthService());
final parkingRepositoryProvider = Provider<ParkingRepository>(
  (ref) => InMemoryParkingRepository(),
);
final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => InMemoryBookingRepository(),
);
final routeProvider = Provider<RouteProvider>((ref) => DemoSeed.routeEngine());
final firebaseReadinessProvider = Provider<FirebaseReadiness>(
  (ref) => const FirebaseReadinessService().check(),
);
final qrPayloadProvider = Provider<QrPayloadService>(
  (ref) => const QrPayloadService(),
);

final userAppControllerProvider =
    StateNotifierProvider<UserAppController, UserAppState>((ref) {
      return UserAppController(
        auth: ref.watch(authServiceProvider),
        parkingRepository: ref.watch(parkingRepositoryProvider),
        bookingRepository: ref.watch(bookingRepositoryProvider),
        routeProvider: ref.watch(routeProvider),
        qrPayloadService: ref.watch(qrPayloadProvider),
      )..load();
    });

class UserAppState {
  const UserAppState({
    required this.user,
    required this.locations,
    required this.bookings,
    required this.routes,
    required this.selectedLocation,
    required this.durationHours,
    required this.isLoading,
    this.error,
  });

  factory UserAppState.initial(AppUser user) {
    return UserAppState(
      user: user,
      locations: const [],
      bookings: const [],
      routes: const [],
      selectedLocation: null,
      durationHours: 2,
      isLoading: true,
    );
  }

  final AppUser user;
  final List<ParkingLocation> locations;
  final List<Booking> bookings;
  final List<RouteOption> routes;
  final ParkingLocation? selectedLocation;
  final int durationHours;
  final bool isLoading;
  final String? error;

  Booking? get activeBooking => bookings
      .where((booking) => booking.status == BookingStatus.active)
      .firstOrNull;

  UserAppState copyWith({
    AppUser? user,
    List<ParkingLocation>? locations,
    List<Booking>? bookings,
    List<RouteOption>? routes,
    ParkingLocation? selectedLocation,
    bool clearSelectedLocation = false,
    int? durationHours,
    bool? isLoading,
    String? error,
  }) {
    return UserAppState(
      user: user ?? this.user,
      locations: locations ?? this.locations,
      bookings: bookings ?? this.bookings,
      routes: routes ?? this.routes,
      selectedLocation: clearSelectedLocation
          ? null
          : selectedLocation ?? this.selectedLocation,
      durationHours: durationHours ?? this.durationHours,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class UserAppController extends StateNotifier<UserAppState> {
  UserAppController({
    required AuthService auth,
    required ParkingRepository parkingRepository,
    required BookingRepository bookingRepository,
    required RouteProvider routeProvider,
    required QrPayloadService qrPayloadService,
  }) : _auth = auth,
       _parkingRepository = parkingRepository,
       _bookingRepository = bookingRepository,
       _routeProvider = routeProvider,
       _qrPayloadService = qrPayloadService,
       super(UserAppState.initial(auth.currentUser));

  final AuthService _auth;
  final ParkingRepository _parkingRepository;
  final BookingRepository _bookingRepository;
  final RouteProvider _routeProvider;
  final QrPayloadService _qrPayloadService;

  static const _currentPosition = RoutePoint(
    id: 'driver_origin',
    label: 'Your location',
    latitude: 12.9722,
    longitude: 77.6081,
  );

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final locations = await _parkingRepository.watchNearby(
      latitude: _currentPosition.latitude,
      longitude: _currentPosition.longitude,
    );
    final bookings = await _bookingRepository.getForUser(_auth.currentUser.id);
    state = state.copyWith(
      locations: locations,
      bookings: bookings,
      selectedLocation: locations.firstOrNull,
      isLoading: false,
    );
    if (locations.isNotEmpty) {
      await selectLocation(locations.first);
    }
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
    required String vehicleNumber,
    required VehicleType vehicleType,
  }) async {
    final user = await _auth.signInUser(
      name: name,
      phone: phone,
      vehicleNumber: vehicleNumber,
      vehicleType: vehicleType,
    );
    state = state.copyWith(user: user);
  }

  Future<void> selectLocation(ParkingLocation location) async {
    final destination = RoutePoint(
      id: location.id,
      label: location.name,
      latitude: location.latitude,
      longitude: location.longitude,
    );
    final routes = await _routeProvider.findRoutes(
      origin: _currentPosition,
      destination: destination,
    );
    state = state.copyWith(selectedLocation: location, routes: routes);
  }

  void changeDuration(int hours) {
    state = state.copyWith(durationHours: hours.clamp(1, 12));
  }

  Future<void> createBooking() async {
    final location = state.selectedLocation;
    if (location == null) {
      state = state.copyWith(error: 'Choose a parking location first.');
      return;
    }
    if (!location.isOpen || location.availableSpaces < 1) {
      state = state.copyWith(
        error: 'This parking location is not available now.',
      );
      return;
    }

    final now = DateTime.now();
    final bookingId = 'book_${now.millisecondsSinceEpoch}';
    final end = now.add(Duration(hours: state.durationHours));
    final price = state.durationHours * location.pricePerHour;
    final payload = _qrPayloadService.buildPayload(
      bookingId: bookingId,
      userId: state.user.id,
      parkingLocationId: location.id,
      vehicleNumber: state.user.vehicleNumber,
      startTime: now,
      endTime: end,
    );
    final booking = Booking(
      id: bookingId,
      userId: state.user.id,
      adminId: location.adminId,
      parkingLocationId: location.id,
      vehicleNumber: state.user.vehicleNumber,
      startTime: now,
      endTime: end,
      price: price,
      status: BookingStatus.active,
      qrPayload: payload,
      createdAt: now,
      updatedAt: now,
    );
    await _bookingRepository.createBooking(booking);
    await _parkingRepository.updateAvailability(
      locationId: location.id,
      totalSpaces: location.totalSpaces,
      availableSpaces: location.availableSpaces - 1,
      isOpen: location.isOpen,
      pricePerHour: location.pricePerHour,
    );
    await load();
    final refreshed = await _parkingRepository.findById(location.id);
    if (refreshed != null) {
      await selectLocation(refreshed);
    }
  }
}
