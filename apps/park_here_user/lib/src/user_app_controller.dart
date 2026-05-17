import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:park_here_shared/park_here_shared.dart';

final authServiceProvider = Provider<AuthService>(
  (ref) => FirebaseAuthService(),
);
final parkingRepositoryProvider = Provider<ParkingRepository>(
  (ref) => FirebaseParkingRepository(),
);
final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => FirebaseBookingRepository(),
);
final imageRepositoryProvider = Provider<ImageRepository>(
  (ref) => FirestoreImageRepository(),
);
final imagePayloadCacheProvider = Provider<ImagePayloadCache>(
  (ref) => ImagePayloadCache(),
);
final userLocationServiceProvider = Provider<UserLocationService>(
  (ref) => GeolocatorUserLocationService(),
);
final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => FirebaseReviewRepository(),
);
final issueRepositoryProvider = Provider<IssueRepository>(
  (ref) => FirebaseIssueRepository(),
);
final routeProvider = Provider<RouteProvider>(
  (ref) => const StraightLineRouteProvider(),
);
final firebaseReadinessProvider = Provider<FirebaseReadiness>(
  (ref) => const FirebaseReadinessService().check(),
);
final qrPayloadProvider = Provider<QrPayloadService>(
  (ref) => const QrPayloadService(),
);

enum UserAuthStatus { checking, signedOut, signedIn }

class UserPosition {
  const UserPosition({
    required this.latitude,
    required this.longitude,
    required this.isFallback,
    required this.message,
  });

  final double latitude;
  final double longitude;
  final bool isFallback;
  final String message;

  RoutePoint toRoutePoint() => RoutePoint(
    id: 'driver_origin',
    label: isFallback ? 'Fallback location' : 'Your location',
    latitude: latitude,
    longitude: longitude,
  );

  double distanceKmTo(ParkingLocation location) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(location.latitude - latitude);
    final dLon = _degreesToRadians(location.longitude - longitude);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(latitude)) *
            cos(_degreesToRadians(location.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _degreesToRadians(double degrees) => degrees * pi / 180;
}

abstract interface class UserLocationService {
  Future<UserPosition> currentPosition();

  Stream<UserPosition> positionStream();
}

class GeolocatorUserLocationService implements UserLocationService {
  static const _fallback = UserPosition(
    latitude: 13.0007,
    longitude: 77.0941,
    isFallback: true,
    message:
        'Location permission is unavailable. Showing parking near SIT Tumkur.',
  );

  @override
  Future<UserPosition> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return _fallback;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return _fallback;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return UserPosition(
      latitude: position.latitude,
      longitude: position.longitude,
      isFallback: false,
      message: 'Using live GPS for nearby parking.',
    );
  }

  @override
  Stream<UserPosition> positionStream() async* {
    final first = await currentPosition();
    yield first;
    if (first.isFallback) {
      return;
    }
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 75,
      ),
    ).map(
      (position) => UserPosition(
        latitude: position.latitude,
        longitude: position.longitude,
        isFallback: false,
        message: 'Using live GPS for nearby parking.',
      ),
    );
  }
}

final userAppControllerProvider =
    StateNotifierProvider<UserAppController, UserAppState>((ref) {
      return UserAppController(
        auth: ref.watch(authServiceProvider),
        parkingRepository: ref.watch(parkingRepositoryProvider),
        bookingRepository: ref.watch(bookingRepositoryProvider),
        imageRepository: ref.watch(imageRepositoryProvider),
        reviewRepository: ref.watch(reviewRepositoryProvider),
        issueRepository: ref.watch(issueRepositoryProvider),
        imageCache: ref.watch(imagePayloadCacheProvider),
        locationService: ref.watch(userLocationServiceProvider),
        routeProvider: ref.watch(routeProvider),
        qrPayloadService: ref.watch(qrPayloadProvider),
      )..load();
    });

class UserAppState {
  const UserAppState({
    required this.user,
    required this.authStatus,
    required this.locations,
    required this.bookings,
    required this.routes,
    required this.thumbnailByArea,
    required this.previewImages,
    required this.selectedReviews,
    required this.activeQrTicket,
    required this.position,
    required this.selectedLocation,
    required this.durationHours,
    required this.isLoading,
    this.actionMessage,
    this.error,
  });

  factory UserAppState.initial(AppUser user) {
    return UserAppState(
      user: user,
      authStatus: UserAuthStatus.checking,
      locations: const [],
      bookings: const [],
      routes: const [],
      thumbnailByArea: const {},
      previewImages: const [],
      selectedReviews: const [],
      activeQrTicket: null,
      position: null,
      selectedLocation: null,
      durationHours: 2,
      isLoading: true,
    );
  }

  factory UserAppState.signedOut() {
    return UserAppState(
      user: null,
      authStatus: UserAuthStatus.signedOut,
      locations: const [],
      bookings: const [],
      routes: const [],
      thumbnailByArea: const {},
      previewImages: const [],
      selectedReviews: const [],
      activeQrTicket: null,
      position: null,
      selectedLocation: null,
      durationHours: 2,
      isLoading: false,
    );
  }

  final AppUser? user;
  final UserAuthStatus authStatus;
  final List<ParkingLocation> locations;
  final List<Booking> bookings;
  final List<RouteOption> routes;
  final Map<String, ParkingAreaImage> thumbnailByArea;
  final List<ParkingAreaImage> previewImages;
  final List<ParkingReview> selectedReviews;
  final ActiveQrTicket? activeQrTicket;
  final UserPosition? position;
  final ParkingLocation? selectedLocation;
  final int durationHours;
  final bool isLoading;
  final String? actionMessage;
  final String? error;

  Booking? get activeBooking => bookings
      .where((booking) => booking.status == BookingStatus.active)
      .firstOrNull;

  double? distanceKmFor(ParkingLocation location) =>
      position?.distanceKmTo(location);

  UserAppState copyWith({
    AppUser? user,
    UserAuthStatus? authStatus,
    List<ParkingLocation>? locations,
    List<Booking>? bookings,
    List<RouteOption>? routes,
    Map<String, ParkingAreaImage>? thumbnailByArea,
    List<ParkingAreaImage>? previewImages,
    List<ParkingReview>? selectedReviews,
    ActiveQrTicket? activeQrTicket,
    bool clearActiveQrTicket = false,
    UserPosition? position,
    ParkingLocation? selectedLocation,
    bool clearSelectedLocation = false,
    int? durationHours,
    bool? isLoading,
    String? actionMessage,
    String? error,
  }) {
    return UserAppState(
      user: user ?? this.user,
      authStatus: authStatus ?? this.authStatus,
      locations: locations ?? this.locations,
      bookings: bookings ?? this.bookings,
      routes: routes ?? this.routes,
      thumbnailByArea: thumbnailByArea ?? this.thumbnailByArea,
      previewImages: previewImages ?? this.previewImages,
      selectedReviews: selectedReviews ?? this.selectedReviews,
      activeQrTicket: clearActiveQrTicket
          ? null
          : activeQrTicket ?? this.activeQrTicket,
      position: position ?? this.position,
      selectedLocation: clearSelectedLocation
          ? null
          : selectedLocation ?? this.selectedLocation,
      durationHours: durationHours ?? this.durationHours,
      isLoading: isLoading ?? this.isLoading,
      actionMessage: actionMessage,
      error: error,
    );
  }
}

class UserAppController extends StateNotifier<UserAppState> {
  UserAppController({
    required AuthService auth,
    required ParkingRepository parkingRepository,
    required BookingRepository bookingRepository,
    required ImageRepository imageRepository,
    required ReviewRepository reviewRepository,
    required IssueRepository issueRepository,
    required ImagePayloadCache imageCache,
    required UserLocationService locationService,
    required RouteProvider routeProvider,
    required QrPayloadService qrPayloadService,
  }) : _auth = auth,
       _parkingRepository = parkingRepository,
       _bookingRepository = bookingRepository,
       _imageRepository = imageRepository,
       _reviewRepository = reviewRepository,
       _issueRepository = issueRepository,
       _imageCache = imageCache,
       _locationService = locationService,
       _routeProvider = routeProvider,
       _qrPayloadService = qrPayloadService,
       super(UserAppState.signedOut());

  final AuthService _auth;
  final ParkingRepository _parkingRepository;
  final BookingRepository _bookingRepository;
  final ImageRepository _imageRepository;
  final ReviewRepository _reviewRepository;
  final IssueRepository _issueRepository;
  final ImagePayloadCache _imageCache;
  final UserLocationService _locationService;
  final RouteProvider _routeProvider;
  final QrPayloadService _qrPayloadService;
  StreamSubscription<UserPosition>? _positionSubscription;
  StreamSubscription<List<ParkingLocation>>? _parkingSubscription;
  StreamSubscription<List<Booking>>? _bookingSubscription;
  StreamSubscription<ActiveQrTicket?>? _activeQrSubscription;
  StreamSubscription<List<ParkingReview>>? _reviewSubscription;

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final user = await _auth.loadCurrentUser();
    if (user == null) {
      state = UserAppState.signedOut();
      return;
    }
    final position = await _locationService.currentPosition();
    _startLocationUpdates();
    _startParkingUpdates();
    _startBookingUpdates(user.id);
    final locations = await _parkingRepository.watchNearby(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    final bookings = await _bookingRepository.getForUser(user.id);
    final activeBooking = bookings
        .where((booking) => booking.status == BookingStatus.active)
        .firstOrNull;
    final activeQrTicket = activeBooking == null
        ? null
        : await _bookingRepository.getActiveQrForBooking(activeBooking.id);
    state = state.copyWith(
      locations: locations,
      bookings: bookings,
      user: user,
      authStatus: UserAuthStatus.signedIn,
      position: position,
      activeQrTicket: activeQrTicket,
      clearActiveQrTicket: activeQrTicket == null,
      selectedLocation: locations.firstOrNull,
      isLoading: false,
    );
    await _loadThumbnails(locations);
    if (locations.isNotEmpty) {
      await selectLocation(locations.first);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _auth.signInUserWithEmail(email: email, password: password);
      await load();
    } on Object catch (error) {
      state = UserAppState.signedOut().copyWith(error: error.toString());
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String vehicleNumber,
    required VehicleType vehicleType,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _auth.signUpUserWithEmail(
        email: email,
        password: password,
        name: name,
        phone: phone,
        vehicleNumber: vehicleNumber,
        vehicleType: vehicleType,
      );
      await load();
    } on Object catch (error) {
      state = UserAppState.signedOut().copyWith(error: error.toString());
    }
  }

  Future<void> signOut() async {
    await _positionSubscription?.cancel();
    await _parkingSubscription?.cancel();
    await _bookingSubscription?.cancel();
    await _activeQrSubscription?.cancel();
    await _reviewSubscription?.cancel();
    _positionSubscription = null;
    _parkingSubscription = null;
    _bookingSubscription = null;
    _activeQrSubscription = null;
    _reviewSubscription = null;
    await _auth.signOut();
    state = UserAppState.signedOut();
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
    state = state.copyWith(user: user, authStatus: UserAuthStatus.signedIn);
  }

  Future<void> selectLocation(ParkingLocation location) async {
    final destination = RoutePoint(
      id: location.id,
      label: location.name,
      latitude: location.latitude,
      longitude: location.longitude,
    );
    final routes = await _routeProvider.findRoutes(
      origin:
          state.position?.toRoutePoint() ??
          const UserPosition(
            latitude: 13.0007,
            longitude: 77.0941,
            isFallback: true,
            message: 'Using SIT Tumkur fallback location.',
          ).toRoutePoint(),
      destination: destination,
    );
    state = state.copyWith(selectedLocation: location, routes: routes);
    await _loadPreviewImages(location);
    await _loadReviews(location.id);
    _startReviewUpdates(location.id);
  }

  void changeDuration(int hours) {
    state = state.copyWith(durationHours: hours.clamp(1, 12));
  }

  Future<void> createBooking() async {
    final location = state.selectedLocation;
    final user = state.user;
    if (location == null) {
      state = state.copyWith(error: 'Choose a parking area first.');
      return;
    }
    if (user == null) {
      state = state.copyWith(error: 'Sign in before booking.');
      return;
    }
    if (!location.isOpen || location.availableSpaces < 1) {
      state = state.copyWith(error: 'This parking area is not available now.');
      return;
    }

    final now = DateTime.now();
    late final ParkingLocation reservedLocation;
    try {
      reservedLocation = await _parkingRepository.reserveSlot(location.id);
    } on StateError catch (error) {
      state = state.copyWith(error: error.message);
      return;
    }
    final bookingId = 'book_${now.millisecondsSinceEpoch}';
    final qrId = 'qr_$bookingId';
    final end = now.add(Duration(hours: state.durationHours));
    final price = state.durationHours * reservedLocation.pricePerHour;
    final payload = _qrPayloadService.buildPayload(
      bookingId: bookingId,
      qrId: qrId,
      userId: user.id,
      parkingLocationId: reservedLocation.id,
      vehicleNumber: user.vehicleNumber,
      startTime: now,
      endTime: end,
    );
    final booking = Booking(
      id: bookingId,
      userId: user.id,
      adminId: reservedLocation.adminId,
      parkingLocationId: reservedLocation.id,
      qrId: qrId,
      vehicleNumber: user.vehicleNumber,
      startTime: now,
      endTime: end,
      price: price,
      status: BookingStatus.active,
      qrPayload: payload,
      createdAt: now,
      updatedAt: now,
    );
    await _bookingRepository.createBooking(booking);
    await _bookingRepository.createActiveQrTicket(booking);
    await load();
    final refreshed = await _parkingRepository.findById(reservedLocation.id);
    if (refreshed != null) {
      await selectLocation(refreshed);
    }
  }

  Future<void> submitReview({
    required int rating,
    required String comment,
  }) async {
    final location = state.selectedLocation;
    final user = state.user;
    if (location == null) {
      state = state.copyWith(error: 'Choose a parking area before reviewing.');
      return;
    }
    if (user == null) {
      state = state.copyWith(error: 'Sign in before reviewing.');
      return;
    }
    final now = DateTime.now();
    final review = ParkingReview(
      reviewId: 'review_${user.id}_${location.id}',
      userId: user.id,
      areaId: location.id,
      rating: rating.clamp(1, 5),
      comment: comment.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _reviewRepository.upsertReview(review);

    final oldTotal = location.ratingAverage * location.ratingCount;
    final newCount = location.ratingCount + 1;
    final refreshedLocation = location.copyWith(
      ratingAverage: (oldTotal + review.rating) / newCount,
      ratingCount: newCount,
      updatedAt: now,
    );
    await _parkingRepository.upsert(refreshedLocation);
    final updatedLocations = state.locations
        .map(
          (item) => item.id == refreshedLocation.id ? refreshedLocation : item,
        )
        .toList();
    state = state.copyWith(
      locations: updatedLocations,
      selectedLocation: refreshedLocation,
      actionMessage: 'Review saved for ${location.name}.',
    );
    await _loadReviews(location.id);
  }

  Future<void> reportIssue({
    required String type,
    required String message,
  }) async {
    final location = state.selectedLocation;
    final user = state.user;
    if (location == null) {
      state = state.copyWith(error: 'Choose a parking area before reporting.');
      return;
    }
    if (user == null) {
      state = state.copyWith(error: 'Sign in before reporting.');
      return;
    }
    final now = DateTime.now();
    await _issueRepository.createIssue(
      IssueReport(
        issueId: 'issue_${now.millisecondsSinceEpoch}',
        userId: user.id,
        areaId: location.id,
        adminId: location.adminId,
        type: type.trim().isEmpty ? 'general' : type.trim(),
        message: message.trim(),
        status: IssueStatus.open,
        createdAt: now,
        updatedAt: now,
      ),
    );
    state = state.copyWith(
      actionMessage: 'Issue sent to ${location.name} owner.',
    );
  }

  Future<void> _loadThumbnails(List<ParkingLocation> locations) async {
    final thumbnails = <String, ParkingAreaImage>{};
    for (final location in locations) {
      final cached = _imageCache.getMany(location.thumbnailRefs).firstOrNull;
      if (cached != null) {
        thumbnails[location.id] = cached;
        continue;
      }
      final images = await _imageRepository.getThumbnailsForArea(
        areaId: location.id,
        limit: 1,
      );
      if (images.isNotEmpty) {
        _imageCache.put(images.first);
        thumbnails[location.id] = images.first;
      }
    }
    state = state.copyWith(thumbnailByArea: thumbnails);
  }

  Future<void> _loadPreviewImages(ParkingLocation location) async {
    final cached = _imageCache.getMany(location.imagePreviewRefs);
    if (cached.isNotEmpty &&
        cached.length == location.imagePreviewRefs.length) {
      state = state.copyWith(previewImages: cached);
      return;
    }
    final images = await _imageRepository.getPreviewsForArea(
      areaId: location.id,
      limit: 6,
    );
    for (final image in images) {
      _imageCache.put(image);
    }
    state = state.copyWith(previewImages: images);
  }

  Future<void> _loadReviews(String areaId) async {
    final reviews = await _reviewRepository.getForArea(areaId, limit: 5);
    state = state.copyWith(selectedReviews: reviews);
  }

  void _startLocationUpdates() {
    if (_positionSubscription != null) {
      return;
    }
    _positionSubscription = _locationService.positionStream().listen((
      position,
    ) async {
      state = state.copyWith(position: position);
      final selected = state.selectedLocation;
      if (selected != null) {
        await selectLocation(selected);
      }
    });
  }

  void _startParkingUpdates() {
    _parkingSubscription ??= _parkingRepository
        .watchByRegion('region_sit_tumkur', limit: 30)
        .listen((locations) async {
          state = state.copyWith(locations: locations);
          await _loadThumbnails(locations);
        });
  }

  void _startBookingUpdates(String userId) {
    _bookingSubscription ??= _bookingRepository
        .watchForUser(userId, limit: 30)
        .listen((bookings) {
          final activeBooking = bookings
              .where((booking) => booking.status == BookingStatus.active)
              .firstOrNull;
          state = state.copyWith(bookings: bookings);
          _startActiveQrUpdates(activeBooking?.id);
        });
  }

  void _startActiveQrUpdates(String? bookingId) {
    _activeQrSubscription?.cancel();
    _activeQrSubscription = null;
    if (bookingId == null) {
      state = state.copyWith(clearActiveQrTicket: true);
      return;
    }
    _activeQrSubscription = _bookingRepository
        .watchActiveQrForBooking(bookingId)
        .listen(
          (ticket) => state = state.copyWith(
            activeQrTicket: ticket,
            clearActiveQrTicket: ticket == null,
          ),
        );
  }

  void _startReviewUpdates(String areaId) {
    _reviewSubscription?.cancel();
    _reviewSubscription = _reviewRepository
        .watchForArea(areaId, limit: 5)
        .listen((reviews) => state = state.copyWith(selectedReviews: reviews));
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _parkingSubscription?.cancel();
    _bookingSubscription?.cancel();
    _activeQrSubscription?.cancel();
    _reviewSubscription?.cancel();
    super.dispose();
  }
}
