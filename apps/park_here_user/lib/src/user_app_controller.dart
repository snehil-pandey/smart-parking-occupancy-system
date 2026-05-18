import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:park_here_shared/park_here_shared.dart';

import 'services/qr_expiry_notification_service.dart';

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
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => FirebaseNotificationRepository(),
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
final placeSearchServiceProvider = Provider<PlaceSearchService>(
  (ref) => const LocalSitTumkurPlaceSearchService(),
);
final qrExpiryNotificationServiceProvider =
    Provider<QrExpiryNotificationService>(
      (ref) => QrExpiryNotificationService(),
    );

enum UserAuthStatus { checking, signedOut, signedIn }

enum UserTab { home, bookings, explore, notifications, profile }

enum ParkingFilter { all, openNow, free, nearest, topRated }

const Object _unset = Object();

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
    latitude: 13.3281211,
    longitude: 77.1256930,
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
        notificationRepository: ref.watch(notificationRepositoryProvider),
        imageCache: ref.watch(imagePayloadCacheProvider),
        locationService: ref.watch(userLocationServiceProvider),
        routeProvider: ref.watch(routeProvider),
        qrPayloadService: ref.watch(qrPayloadProvider),
        placeSearchService: ref.watch(placeSearchServiceProvider),
        qrExpiryNotificationService: ref.watch(
          qrExpiryNotificationServiceProvider,
        ),
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
    required this.notifications,
    required this.activeQrTicket,
    required this.position,
    required this.selectedLocation,
    required this.selectedPlace,
    required this.searchQuery,
    required this.searchResults,
    required this.parkingFilter,
    required this.currentTab,
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
      notifications: const [],
      activeQrTicket: null,
      position: null,
      selectedLocation: null,
      selectedPlace: null,
      searchQuery: '',
      searchResults: const [],
      parkingFilter: ParkingFilter.all,
      currentTab: UserTab.home,
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
      notifications: const [],
      activeQrTicket: null,
      position: null,
      selectedLocation: null,
      selectedPlace: null,
      searchQuery: '',
      searchResults: const [],
      parkingFilter: ParkingFilter.all,
      currentTab: UserTab.home,
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
  final List<AppNotification> notifications;
  final ActiveQrTicket? activeQrTicket;
  final UserPosition? position;
  final ParkingLocation? selectedLocation;
  final PlaceSearchResult? selectedPlace;
  final String searchQuery;
  final List<PlaceSearchResult> searchResults;
  final ParkingFilter parkingFilter;
  final UserTab currentTab;
  final int durationHours;
  final bool isLoading;
  final String? actionMessage;
  final String? error;

  Booking? get activeBooking => bookings
      .where((booking) => booking.status == BookingStatus.active)
      .firstOrNull;

  double? distanceKmFor(ParkingLocation location) =>
      position?.distanceKmTo(location);

  List<ParkingLocation> get visibleLocations {
    final filtered = switch (parkingFilter) {
      ParkingFilter.all => locations,
      ParkingFilter.openNow =>
        locations.where((location) => location.isBookable).toList(),
      ParkingFilter.free =>
        locations.where((location) => location.pricePerHour == 0).toList(),
      ParkingFilter.nearest =>
        [...locations]..sort(
          (a, b) => (distanceKmFor(a) ?? double.infinity).compareTo(
            distanceKmFor(b) ?? double.infinity,
          ),
        ),
      ParkingFilter.topRated => [
        ...locations,
      ]..sort((a, b) => b.ratingAverage.compareTo(a.ratingAverage)),
    };
    return filtered;
  }

  List<ParkingLocation> get topRatedLocations =>
      [...locations]
        ..sort((a, b) => b.ratingAverage.compareTo(a.ratingAverage));

  List<ParkingLocation> get cheapestLocations =>
      [...locations]..sort((a, b) => a.pricePerHour.compareTo(b.pricePerHour));

  List<ParkingLocation> get freeLocations =>
      locations.where((location) => location.pricePerHour == 0).toList();

  List<ParkingLocation> get nearbyAvailableLocations =>
      locations.where((location) => location.isBookable).toList()..sort(
        (a, b) => (distanceKmFor(a) ?? double.infinity).compareTo(
          distanceKmFor(b) ?? double.infinity,
        ),
      );

  List<ParkingLocation> get recentlyUsedLocations {
    final seen = <String>{};
    final results = <ParkingLocation>[];
    for (final booking in bookingHistory) {
      if (!seen.add(booking.parkingLocationId)) {
        continue;
      }
      final location = locations
          .where((area) => area.id == booking.parkingLocationId)
          .firstOrNull;
      if (location != null) {
        results.add(location);
      }
    }
    return results;
  }

  List<Booking> get bookingHistory =>
      [...bookings]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  UserAppState copyWith({
    AppUser? user,
    UserAuthStatus? authStatus,
    List<ParkingLocation>? locations,
    List<Booking>? bookings,
    List<RouteOption>? routes,
    Map<String, ParkingAreaImage>? thumbnailByArea,
    List<ParkingAreaImage>? previewImages,
    List<ParkingReview>? selectedReviews,
    List<AppNotification>? notifications,
    ActiveQrTicket? activeQrTicket,
    bool clearActiveQrTicket = false,
    UserPosition? position,
    ParkingLocation? selectedLocation,
    bool clearSelectedLocation = false,
    PlaceSearchResult? selectedPlace,
    bool clearSelectedPlace = false,
    String? searchQuery,
    List<PlaceSearchResult>? searchResults,
    ParkingFilter? parkingFilter,
    UserTab? currentTab,
    int? durationHours,
    bool? isLoading,
    String? actionMessage,
    Object? error = _unset,
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
      notifications: notifications ?? this.notifications,
      activeQrTicket: clearActiveQrTicket
          ? null
          : activeQrTicket ?? this.activeQrTicket,
      position: position ?? this.position,
      selectedLocation: clearSelectedLocation
          ? null
          : selectedLocation ?? this.selectedLocation,
      selectedPlace: clearSelectedPlace
          ? null
          : selectedPlace ?? this.selectedPlace,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      parkingFilter: parkingFilter ?? this.parkingFilter,
      currentTab: currentTab ?? this.currentTab,
      durationHours: durationHours ?? this.durationHours,
      isLoading: isLoading ?? this.isLoading,
      actionMessage: actionMessage,
      error: identical(error, _unset) ? this.error : error?.toString(),
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
    required NotificationRepository notificationRepository,
    required ImagePayloadCache imageCache,
    required UserLocationService locationService,
    required RouteProvider routeProvider,
    required QrPayloadService qrPayloadService,
    required PlaceSearchService placeSearchService,
    required QrExpiryNotificationService qrExpiryNotificationService,
  }) : _auth = auth,
       _parkingRepository = parkingRepository,
       _bookingRepository = bookingRepository,
       _imageRepository = imageRepository,
       _reviewRepository = reviewRepository,
       _issueRepository = issueRepository,
       _notificationRepository = notificationRepository,
       _imageCache = imageCache,
       _locationService = locationService,
       _routeProvider = routeProvider,
       _qrPayloadService = qrPayloadService,
       _placeSearchService = placeSearchService,
       _qrExpiryNotificationService = qrExpiryNotificationService,
       super(UserAppState.signedOut());

  final AuthService _auth;
  final ParkingRepository _parkingRepository;
  final BookingRepository _bookingRepository;
  final ImageRepository _imageRepository;
  final ReviewRepository _reviewRepository;
  final IssueRepository _issueRepository;
  final NotificationRepository _notificationRepository;
  final ImagePayloadCache _imageCache;
  final UserLocationService _locationService;
  final RouteProvider _routeProvider;
  final QrPayloadService _qrPayloadService;
  final PlaceSearchService _placeSearchService;
  final QrExpiryNotificationService _qrExpiryNotificationService;
  StreamSubscription<UserPosition>? _positionSubscription;
  StreamSubscription<List<ParkingLocation>>? _parkingSubscription;
  StreamSubscription<List<Booking>>? _bookingSubscription;
  StreamSubscription<ActiveQrTicket?>? _activeQrSubscription;
  StreamSubscription<List<ParkingReview>>? _reviewSubscription;
  StreamSubscription<List<AppNotification>>? _notificationSubscription;
  Timer? _searchDebounce;
  Timer? _qrCountdownTimer;
  final Set<String> _notifiedQrThresholds = {};

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    final user = await _auth.loadCurrentUser();
    if (user == null) {
      state = UserAppState.signedOut();
      return;
    }
    final position = await _locationService.currentPosition();
    await _resetRealtimeSubscriptions();
    _startLocationUpdates();
    _startParkingUpdates();
    _startBookingUpdates(user.id);
    _startNotificationUpdates(user.id);
    var locations = state.locations;
    var bookings = state.bookings;
    try {
      locations = await _parkingRepository.watchNearby(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      bookings = await _bookingRepository.getForUser(user.id);
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
        error: null,
      );
      await _loadThumbnails(locations);
      if (locations.isNotEmpty) {
        await selectLocation(locations.first);
      }
    } on Object catch (error) {
      state = state.copyWith(
        locations: locations,
        bookings: bookings,
        user: user,
        authStatus: UserAuthStatus.signedIn,
        position: position,
        isLoading: false,
        error: FirebaseErrorMessages.friendlyMessage(error),
      );
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
    await _resetRealtimeSubscriptions();
    _positionSubscription = null;
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
            latitude: 13.3281211,
            longitude: 77.1256930,
            isFallback: true,
            message: 'Using SIT Tumkur fallback location.',
          ).toRoutePoint(),
      destination: destination,
    );
    state = state.copyWith(
      selectedLocation: location,
      clearSelectedPlace: true,
      routes: routes,
      currentTab: UserTab.home,
    );
    await _loadPreviewImages(location);
    await _loadReviews(location.id);
    _startReviewUpdates(location.id);
  }

  void changeTab(UserTab tab) {
    state = state.copyWith(currentTab: tab);
  }

  void changeFilter(ParkingFilter filter) {
    state = state.copyWith(parkingFilter: filter);
  }

  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 260), () async {
      final trimmed = query.trim();
      if (trimmed.isEmpty) {
        state = state.copyWith(searchResults: const []);
        return;
      }
      final areaResults = await _placeSearchService.searchParkingAreas(
        query: trimmed,
        parkingAreas: state.locations,
      );
      final placeResults = await _placeSearchService.searchPlaces(trimmed);
      state = state.copyWith(
        searchResults: [...areaResults, ...placeResults].take(10).toList(),
      );
    });
  }

  Future<void> selectSearchResult(PlaceSearchResult result) async {
    if (result.isCurrentLocation) {
      final position = await _locationService.currentPosition();
      state = state.copyWith(
        position: position,
        selectedPlace: PlaceSearchResult(
          id: result.id,
          title: result.title,
          subtitle: position.message,
          latitude: position.latitude,
          longitude: position.longitude,
          isCurrentLocation: true,
        ),
        searchResults: const [],
        searchQuery: result.title,
        currentTab: UserTab.home,
      );
      return;
    }
    final areaId = result.parkingAreaId;
    if (areaId != null) {
      final match = state.locations
          .where((location) => location.id == areaId)
          .firstOrNull;
      if (match != null) {
        state = state.copyWith(
          searchResults: const [],
          searchQuery: result.title,
        );
        await selectLocation(match);
        return;
      }
    }
    state = state.copyWith(
      selectedPlace: result,
      searchResults: const [],
      searchQuery: result.title,
      currentTab: UserTab.home,
      clearSelectedLocation: true,
    );
  }

  void clearSearch() {
    _searchDebounce?.cancel();
    state = state.copyWith(
      searchQuery: '',
      searchResults: const [],
      clearSelectedPlace: true,
    );
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
    final qrId = _qrPayloadService.generateQrId();
    final end = now.add(Duration(hours: state.durationHours));
    final price = state.durationHours * reservedLocation.pricePerHour;
    final payload = _qrPayloadService.buildPayload(qrId: qrId);
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
    await _notificationRepository.upsert(
      AppNotification(
        notificationId: 'notif_booking_$bookingId',
        userId: user.id,
        type: AppNotificationType.bookingConfirmed,
        title: 'Booking confirmed',
        message: '${reservedLocation.name} is reserved until ${_clock(end)}.',
        relatedBookingId: bookingId,
        relatedAreaId: reservedLocation.id,
        read: false,
        createdAt: now,
      ),
    );
    await load();
    final refreshed = await _parkingRepository.findById(reservedLocation.id);
    if (refreshed != null) {
      await selectLocation(refreshed);
    }
  }

  Future<void> cancelActiveBooking({String? reason}) async {
    final booking = state.activeBooking;
    if (booking == null) {
      state = state.copyWith(error: 'No active booking to cancel.');
      return;
    }
    try {
      final cancelled = await _bookingRepository.cancelBooking(
        bookingId: booking.id,
        reason: reason,
      );
      state = state.copyWith(
        actionMessage: cancelled.cancellationFine > 0
            ? 'Booking cancelled. Fine: ${formatInr(cancelled.cancellationFine)}.'
            : 'Booking cancelled with no fine.',
      );
      await _notificationRepository.upsert(
        AppNotification(
          notificationId: 'notif_cancel_${booking.id}',
          userId: booking.userId,
          type: AppNotificationType.bookingCancelled,
          title: 'Booking cancelled',
          message: cancelled.cancellationFine > 0
              ? 'Cancellation fine recorded: ${formatInr(cancelled.cancellationFine)}.'
              : 'Booking cancelled with no fine.',
          relatedBookingId: booking.id,
          relatedAreaId: booking.parkingLocationId,
          read: false,
          createdAt: DateTime.now(),
        ),
      );
      await _qrExpiryNotificationService.cancelScheduled();
      await load();
    } on Object catch (error) {
      state = state.copyWith(error: error.toString());
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
    try {
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
    } on Object catch (error) {
      state = state.copyWith(
        thumbnailByArea: thumbnails,
        error: FirebaseErrorMessages.friendlyMessage(error),
      );
    }
  }

  Future<void> _loadPreviewImages(ParkingLocation location) async {
    final cached = _imageCache.getMany(location.imagePreviewRefs);
    if (cached.isNotEmpty &&
        cached.length == location.imagePreviewRefs.length) {
      state = state.copyWith(previewImages: cached);
      return;
    }
    try {
      final images = await _imageRepository.getPreviewsForArea(
        areaId: location.id,
        limit: 6,
      );
      for (final image in images) {
        _imageCache.put(image);
      }
      state = state.copyWith(previewImages: images);
    } on Object catch (error) {
      state = state.copyWith(
        previewImages: const [],
        error: FirebaseErrorMessages.friendlyMessage(error),
      );
    }
  }

  Future<void> _loadReviews(String areaId) async {
    try {
      final reviews = await _reviewRepository.getForArea(areaId, limit: 5);
      state = state.copyWith(selectedReviews: reviews);
    } on Object catch (error) {
      state = state.copyWith(
        selectedReviews: const [],
        error: FirebaseErrorMessages.friendlyMessage(error),
      );
    }
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
        .listen(
          (locations) async {
            state = state.copyWith(locations: locations);
            await _loadThumbnails(locations);
          },
          onError: (Object error) {
            state = state.copyWith(
              isLoading: false,
              error: FirebaseErrorMessages.friendlyMessage(error),
            );
          },
        );
  }

  void _startBookingUpdates(String userId) {
    _bookingSubscription ??= _bookingRepository
        .watchForUser(userId, limit: 30)
        .listen(
          (bookings) {
            final activeBooking = bookings
                .where((booking) => booking.status == BookingStatus.active)
                .firstOrNull;
            state = state.copyWith(bookings: bookings);
            _startActiveQrUpdates(activeBooking?.id);
            if (activeBooking == null) {
              _qrExpiryNotificationService.cancelScheduled();
              _qrCountdownTimer?.cancel();
              _notifiedQrThresholds.clear();
            }
          },
          onError: (Object error) {
            state = state.copyWith(
              isLoading: false,
              error: FirebaseErrorMessages.friendlyMessage(error),
            );
          },
        );
  }

  void _startNotificationUpdates(String userId) {
    _notificationSubscription ??= _notificationRepository
        .watchForUser(userId, limit: 30)
        .listen(
          (notifications) =>
              state = state.copyWith(notifications: notifications),
          onError: (Object error) {
            state = state.copyWith(
              error: FirebaseErrorMessages.friendlyMessage(error),
            );
          },
        );
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
          (ticket) {
            state = state.copyWith(
              activeQrTicket: ticket,
              clearActiveQrTicket: ticket == null,
            );
            _syncQrExpiryNotifications(ticket);
          },
          onError: (Object error) {
            state = state.copyWith(
              error: FirebaseErrorMessages.friendlyMessage(error),
            );
          },
        );
  }

  void _syncQrExpiryNotifications(ActiveQrTicket? ticket) {
    final booking = state.activeBooking;
    final location = booking == null
        ? null
        : state.locations
              .where((area) => area.id == booking.parkingLocationId)
              .firstOrNull;
    _qrExpiryNotificationService.scheduleForTicket(
      ticket: ticket,
      parkingName: location?.name ?? 'your parking area',
    );
    _qrCountdownTimer?.cancel();
    if (ticket == null || booking == null) {
      _notifiedQrThresholds.clear();
      return;
    }
    _qrCountdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkQrExpiryThresholds(ticket, booking, location);
    });
    _checkQrExpiryThresholds(ticket, booking, location);
  }

  Future<void> _checkQrExpiryThresholds(
    ActiveQrTicket ticket,
    Booking booking,
    ParkingLocation? location,
  ) async {
    final remaining = ticket.expiresAt.difference(DateTime.now());
    final user = state.user;
    if (user == null) {
      return;
    }
    if (remaining.isNegative) {
      await _writeQrNotification(
        id: '${ticket.qrId}_expired',
        userId: user.id,
        type: AppNotificationType.qrExpired,
        title: 'QR expired',
        message:
            'Your QR for ${location?.name ?? booking.parkingLocationId} has expired.',
        booking: booking,
      );
      return;
    }
    if (remaining <= const Duration(minutes: 2)) {
      await _writeQrNotification(
        id: '${ticket.qrId}_2',
        userId: user.id,
        type: AppNotificationType.qrExpiringSoon,
        title: 'QR expires in 2 minutes',
        message:
            'Keep your QR ready for ${location?.name ?? 'gate verification'}.',
        booking: booking,
      );
    } else if (remaining <= const Duration(minutes: 10)) {
      await _writeQrNotification(
        id: '${ticket.qrId}_10',
        userId: user.id,
        type: AppNotificationType.qrExpiringSoon,
        title: 'QR expires in 10 minutes',
        message:
            'Your Park Here ticket for ${location?.name ?? booking.parkingLocationId} is expiring soon.',
        booking: booking,
      );
    }
  }

  Future<void> _writeQrNotification({
    required String id,
    required String userId,
    required AppNotificationType type,
    required String title,
    required String message,
    required Booking booking,
  }) async {
    if (!_notifiedQrThresholds.add(id)) {
      return;
    }
    state = state.copyWith(actionMessage: message);
    await _notificationRepository.upsert(
      AppNotification(
        notificationId: 'notif_$id',
        userId: userId,
        type: type,
        title: title,
        message: message,
        relatedBookingId: booking.id,
        relatedAreaId: booking.parkingLocationId,
        read: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  void _startReviewUpdates(String areaId) {
    _reviewSubscription?.cancel();
    _reviewSubscription = _reviewRepository
        .watchForArea(areaId, limit: 5)
        .listen(
          (reviews) => state = state.copyWith(selectedReviews: reviews),
          onError: (Object error) {
            state = state.copyWith(
              error: FirebaseErrorMessages.friendlyMessage(error),
            );
          },
        );
  }

  Future<void> _resetRealtimeSubscriptions() async {
    await _parkingSubscription?.cancel();
    await _bookingSubscription?.cancel();
    await _activeQrSubscription?.cancel();
    await _reviewSubscription?.cancel();
    await _notificationSubscription?.cancel();
    _qrCountdownTimer?.cancel();
    await _qrExpiryNotificationService.cancelScheduled();
    _parkingSubscription = null;
    _bookingSubscription = null;
    _activeQrSubscription = null;
    _reviewSubscription = null;
    _notificationSubscription = null;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _positionSubscription?.cancel();
    _parkingSubscription?.cancel();
    _bookingSubscription?.cancel();
    _activeQrSubscription?.cancel();
    _reviewSubscription?.cancel();
    _notificationSubscription?.cancel();
    _qrCountdownTimer?.cancel();
    super.dispose();
  }

  String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
