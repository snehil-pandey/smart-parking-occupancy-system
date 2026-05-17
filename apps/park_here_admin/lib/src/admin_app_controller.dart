import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:park_here_shared/park_here_shared.dart';

final adminAuthProvider = Provider<AuthService>((ref) => LocalAuthService());
final adminParkingRepositoryProvider = Provider<ParkingRepository>(
  (ref) => InMemoryParkingRepository(),
);
final adminBookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => InMemoryBookingRepository(),
);
final adminFirebaseReadinessProvider = Provider<FirebaseReadiness>(
  (ref) => const FirebaseReadinessService().check(),
);

final adminAppControllerProvider =
    StateNotifierProvider<AdminAppController, AdminAppState>((ref) {
      return AdminAppController(
        auth: ref.watch(adminAuthProvider),
        parkingRepository: ref.watch(adminParkingRepositoryProvider),
        bookingRepository: ref.watch(adminBookingRepositoryProvider),
      )..load();
    });

class AdminAppState {
  const AdminAppState({
    required this.admin,
    required this.locations,
    required this.bookings,
    required this.selectedLocation,
    required this.isLoading,
    this.error,
  });

  factory AdminAppState.initial(AdminProfile admin) {
    return AdminAppState(
      admin: admin,
      locations: const [],
      bookings: const [],
      selectedLocation: null,
      isLoading: true,
    );
  }

  final AdminProfile admin;
  final List<ParkingLocation> locations;
  final List<Booking> bookings;
  final ParkingLocation? selectedLocation;
  final bool isLoading;
  final String? error;

  int get totalSpaces =>
      locations.fold(0, (total, location) => total + location.totalSpaces);

  int get availableSpaces =>
      locations.fold(0, (total, location) => total + location.availableSpaces);

  int get activeBookings => bookings
      .where((booking) => booking.status == BookingStatus.active)
      .length;

  double get todaysIncome {
    final now = DateTime.now();
    return bookings
        .where(
          (booking) =>
              booking.createdAt.year == now.year &&
              booking.createdAt.month == now.month &&
              booking.createdAt.day == now.day &&
              booking.status != BookingStatus.cancelled,
        )
        .fold(0, (total, booking) => total + booking.price);
  }

  AdminAppState copyWith({
    AdminProfile? admin,
    List<ParkingLocation>? locations,
    List<Booking>? bookings,
    ParkingLocation? selectedLocation,
    bool? isLoading,
    String? error,
  }) {
    return AdminAppState(
      admin: admin ?? this.admin,
      locations: locations ?? this.locations,
      bookings: bookings ?? this.bookings,
      selectedLocation: selectedLocation ?? this.selectedLocation,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AdminAppController extends StateNotifier<AdminAppState> {
  AdminAppController({
    required AuthService auth,
    required ParkingRepository parkingRepository,
    required BookingRepository bookingRepository,
  }) : _auth = auth,
       _parkingRepository = parkingRepository,
       _bookingRepository = bookingRepository,
       super(AdminAppState.initial(auth.currentAdmin));

  final AuthService _auth;
  final ParkingRepository _parkingRepository;
  final BookingRepository _bookingRepository;

  Future<void> load() async {
    final locations = await _parkingRepository.getByAdmin(
      _auth.currentAdmin.id,
    );
    final bookings = await _bookingRepository.getForAdmin(
      _auth.currentAdmin.id,
    );
    state = state.copyWith(
      locations: locations,
      bookings: bookings,
      selectedLocation: locations.firstOrNull,
      isLoading: false,
    );
  }

  Future<void> updateAdminProfile({
    required String businessName,
    required String ownerName,
    required String phone,
    String? upiId,
  }) async {
    final admin = await _auth.signInAdmin(
      businessName: businessName,
      ownerName: ownerName,
      phone: phone,
      upiId: upiId,
    );
    state = state.copyWith(admin: admin);
    await load();
  }

  void selectLocation(ParkingLocation location) {
    state = state.copyWith(selectedLocation: location);
  }

  Future<void> registerLocation({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required int totalSpaces,
    required int availableSpaces,
    required double pricePerHour,
    required List<VehicleType> vehicleTypes,
    required String openingTime,
    required String closingTime,
    required List<String> imageUrls,
  }) async {
    final now = DateTime.now();
    final location = ParkingLocation(
      id: 'loc_${now.millisecondsSinceEpoch}',
      adminId: state.admin.id,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      totalSpaces: totalSpaces,
      availableSpaces: availableSpaces.clamp(0, totalSpaces),
      pricePerHour: pricePerHour,
      vehicleTypes: vehicleTypes,
      imageUrls: imageUrls,
      isOpen: true,
      openingTime: openingTime,
      closingTime: closingTime,
      createdAt: now,
      updatedAt: now,
    );
    await _parkingRepository.upsert(location);
    await load();
    state = state.copyWith(selectedLocation: location);
  }

  Future<void> updateSelectedAvailability({
    required int totalSpaces,
    required int availableSpaces,
    required bool isOpen,
    required double pricePerHour,
  }) async {
    final location = state.selectedLocation;
    if (location == null) {
      return;
    }
    await _parkingRepository.updateAvailability(
      locationId: location.id,
      totalSpaces: totalSpaces,
      availableSpaces: availableSpaces,
      isOpen: isOpen,
      pricePerHour: pricePerHour,
    );
    await load();
    final refreshed = await _parkingRepository.findById(location.id);
    if (refreshed != null) {
      state = state.copyWith(selectedLocation: refreshed);
    }
  }

  Future<void> markCompleted(Booking booking) async {
    await _bookingRepository.updateStatus(
      bookingId: booking.id,
      status: BookingStatus.completed,
    );
    await load();
  }
}
