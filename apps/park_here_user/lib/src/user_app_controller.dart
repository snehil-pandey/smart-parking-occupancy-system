import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
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
  (ref) => OsrmRouteProvider(fallback: SitTumkurRoadGraphRouteProvider()),
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

ParkingFilter toggleParkingFilter(ParkingFilter current, ParkingFilter tapped) {
  if (tapped == ParkingFilter.all || current == tapped) {
    return ParkingFilter.all;
  }
  return tapped;
}

const Object _unset = Object();

class UserBookingConfirmation {
  const UserBookingConfirmation({
    required this.booking,
    required this.location,
    required this.ticket,
  });

  final Booking booking;
  final ParkingLocation location;
  final ActiveQrTicket ticket;

  String get shortTicketId => ticket.qrId.length <= 14
      ? ticket.qrId
      : '${ticket.qrId.substring(0, 14)}...';
}

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
    required this.selectedRouteId,
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
    required this.isRefreshingData,
    required this.isBookingInProgress,
    required this.isRouteLoading,
    required this.loadingMessage,
    this.bookingConfirmation,
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
      selectedRouteId: null,
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
      isRefreshingData: false,
      isBookingInProgress: false,
      isRouteLoading: false,
      loadingMessage: 'Restoring your parking dashboard...',
    );
  }

  factory UserAppState.checking() {
    return UserAppState(
      user: null,
      authStatus: UserAuthStatus.checking,
      locations: const [],
      bookings: const [],
      routes: const [],
      selectedRouteId: null,
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
      isRefreshingData: false,
      isBookingInProgress: false,
      isRouteLoading: false,
      loadingMessage: 'Checking your session...',
    );
  }

  factory UserAppState.signedOut() {
    return UserAppState(
      user: null,
      authStatus: UserAuthStatus.signedOut,
      locations: const [],
      bookings: const [],
      routes: const [],
      selectedRouteId: null,
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
      isRefreshingData: false,
      isBookingInProgress: false,
      isRouteLoading: false,
      loadingMessage: 'Connecting to Park Here...',
    );
  }

  final AppUser? user;
  final UserAuthStatus authStatus;
  final List<ParkingLocation> locations;
  final List<Booking> bookings;
  final List<RouteOption> routes;
  final String? selectedRouteId;
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
  final bool isRefreshingData;
  final bool isBookingInProgress;
  final bool isRouteLoading;
  final String loadingMessage;
  final UserBookingConfirmation? bookingConfirmation;
  final String? actionMessage;
  final String? error;

  Booking? get activeBooking =>
      bookings.where((booking) => booking.isCurrentSession).firstOrNull;

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

  RouteOption? get selectedRoute =>
      routes.where((route) => route.id == selectedRouteId).firstOrNull ??
      routes.where((route) => route.isBest).firstOrNull ??
      routes.firstOrNull;

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
    String? selectedRouteId,
    bool clearSelectedRoute = false,
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
    bool? isRefreshingData,
    bool? isBookingInProgress,
    bool? isRouteLoading,
    String? loadingMessage,
    UserBookingConfirmation? bookingConfirmation,
    bool clearBookingConfirmation = false,
    String? actionMessage,
    Object? error = _unset,
  }) {
    return UserAppState(
      user: user ?? this.user,
      authStatus: authStatus ?? this.authStatus,
      locations: locations ?? this.locations,
      bookings: bookings ?? this.bookings,
      routes: routes ?? this.routes,
      selectedRouteId: clearSelectedRoute
          ? null
          : selectedRouteId ?? this.selectedRouteId,
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
      isRefreshingData: isRefreshingData ?? this.isRefreshingData,
      isBookingInProgress: isBookingInProgress ?? this.isBookingInProgress,
      isRouteLoading: isRouteLoading ?? this.isRouteLoading,
      loadingMessage: loadingMessage ?? this.loadingMessage,
      bookingConfirmation: clearBookingConfirmation
          ? null
          : bookingConfirmation ?? this.bookingConfirmation,
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
       super(UserAppState.checking());

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
  final ParkingGateSelector _gateSelector = const ParkingGateSelector();
  StreamSubscription<UserPosition>? _positionSubscription;
  StreamSubscription<List<ParkingLocation>>? _parkingSubscription;
  StreamSubscription<List<Booking>>? _bookingSubscription;
  StreamSubscription<ActiveQrTicket?>? _activeQrSubscription;
  String? _activeQrBookingId;
  StreamSubscription<List<ParkingReview>>? _reviewSubscription;
  StreamSubscription<List<AppNotification>>? _notificationSubscription;
  Timer? _searchDebounce;
  Timer? _routeDebounce;
  Timer? _qrCountdownTimer;
  String? _lastRouteKey;
  int _routeRequestId = 0;
  final Set<String> _notifiedQrThresholds = {};

  Future<void> load() async {
    state = state.copyWith(
      authStatus: UserAuthStatus.checking,
      isLoading: true,
      loadingMessage: 'Checking your session...',
      error: null,
    );
    final user = await _auth.loadCurrentUser();
    if (user == null) {
      state = UserAppState.signedOut();
      return;
    }
    state = state.copyWith(
      user: user,
      authStatus: UserAuthStatus.checking,
      loadingMessage: 'Restoring your parking dashboard...',
    );
    var locations = state.locations;
    var bookings = state.bookings;
    UserPosition? position;
    try {
      position = await _locationService.currentPosition();
      locations = _userVisibleParkingAreas(
        await _parkingRepository.watchNearby(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
      bookings = await _bookingRepository.getForUser(user.id);
      final activeBooking = bookings
          .where((booking) => booking.isCurrentSession)
          .firstOrNull;
      final activeQrTicket =
          activeBooking == null || activeBooking.isParkingActive
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
        loadingMessage: 'Connected to Park Here.',
        error: null,
      );
      await _resetRealtimeSubscriptions();
      _startLocationUpdates();
      _startParkingUpdates();
      _startBookingUpdates(user.id);
      _startNotificationUpdates(user.id);
      unawaited(_loadThumbnails(locations));
      final first = locations.firstOrNull;
      if (first != null) {
        _scheduleRouteRefresh(first);
      }
    } on Object catch (error) {
      state = state.copyWith(
        locations: locations,
        bookings: bookings,
        user: user,
        authStatus: UserAuthStatus.signedIn,
        position: position,
        isLoading: false,
        loadingMessage: 'Connected to Park Here.',
        error: FirebaseErrorMessages.friendlyMessage(error),
      );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(
      isLoading: true,
      loadingMessage: 'Restoring your parking dashboard...',
      error: null,
    );
    try {
      await _auth.signInUserWithEmail(email: email, password: password);
      await load();
    } on Object catch (error) {
      debugPrint('User sign-in failed: $error');
      state = UserAppState.signedOut().copyWith(
        error: 'Unable to sign in. Check your details and try again.',
      );
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
    state = state.copyWith(
      isLoading: true,
      loadingMessage: 'Creating your Park Here account...',
      error: null,
    );
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
      debugPrint('User sign-up failed: $error');
      state = UserAppState.signedOut().copyWith(
        error: 'Unable to create account. Please try again.',
      );
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
    if (!location.isUserVisibleParkingArea) {
      state = state.copyWith(
        error: 'Please select a parking area inside this region.',
      );
      return;
    }
    state = state.copyWith(
      selectedLocation: location,
      clearSelectedPlace: true,
      currentTab: UserTab.home,
    );
    _scheduleRouteRefresh(location);
    unawaited(_loadPreviewImages(location));
    unawaited(_loadReviews(location.id));
    _startReviewUpdates(location.id);
  }

  void selectRoute(String routeId) {
    final selected = state.routes.where((route) => route.id == routeId);
    if (selected.isEmpty) {
      return;
    }
    state = state.copyWith(selectedRouteId: routeId);
  }

  void changeTab(UserTab tab) {
    state = state.copyWith(currentTab: tab);
  }

  void changeFilter(ParkingFilter filter) {
    // Single-select chips behave like toggles: tapping the active chip clears
    // back to the unfiltered view while realtime data keeps streaming in.
    state = state.copyWith(
      parkingFilter: toggleParkingFilter(state.parkingFilter, filter),
    );
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
      if (state.searchQuery.trim() != trimmed) {
        return;
      }
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

  void clearBookingConfirmation() {
    state = state.copyWith(clearBookingConfirmation: true);
  }

  Future<void> retryRealtime() async {
    final user = state.user;
    if (user == null) {
      await load();
      return;
    }
    state = state.copyWith(isRefreshingData: true, error: null);
    await _resetRealtimeSubscriptions();
    _startParkingUpdates();
    _startBookingUpdates(user.id);
    _startNotificationUpdates(user.id);
    state = state.copyWith(isRefreshingData: false);
  }

  Future<void> createBooking() async {
    if (state.isBookingInProgress) {
      return;
    }
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
    if (!location.isUserVisibleParkingArea) {
      state = state.copyWith(
        error: 'Please select a parking area inside this region.',
      );
      return;
    }
    if (!location.isBookable) {
      state = state.copyWith(error: 'This parking area is not available now.');
      return;
    }
    if (state.activeBooking != null) {
      state = state.copyWith(
        error: 'You already have an active parking booking.',
      );
      return;
    }
    state = state.copyWith(
      isBookingInProgress: true,
      clearBookingConfirmation: true,
      error: null,
    );
    Booking? existingActive;
    try {
      existingActive = await _bookingRepository.activeForUser(user.id);
    } on Object catch (error) {
      state = state.copyWith(
        isBookingInProgress: false,
        error: FirebaseErrorMessages.friendlyMessage(error),
      );
      return;
    }
    if (existingActive != null) {
      state = state.copyWith(
        isBookingInProgress: false,
        error: 'You already have an active parking booking.',
      );
      return;
    }

    final now = DateTime.now();
    late final ParkingLocation reservedLocation;
    try {
      reservedLocation = await _parkingRepository.reserveSlot(location.id);
    } on StateError catch (error) {
      final message = error.message.contains('no available slots')
          ? 'Parking just became full. Please choose another area.'
          : error.message;
      state = state.copyWith(isBookingInProgress: false, error: message);
      return;
    } on Object catch (error) {
      state = state.copyWith(
        isBookingInProgress: false,
        error: FirebaseErrorMessages.friendlyMessage(error),
      );
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
      status: BookingStatus.confirmed,
      qrPayload: payload,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _bookingRepository.createBooking(booking);
      final ticket = await _bookingRepository.createActiveQrTicket(booking);
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
      final locations = state.locations
          .map(
            (item) => item.id == reservedLocation.id ? reservedLocation : item,
          )
          .toList();
      state = state.copyWith(
        locations: locations,
        selectedLocation: reservedLocation,
        bookings: _mergeBooking(state.bookings, booking),
        activeQrTicket: ticket,
        isBookingInProgress: false,
        actionMessage: 'Booking confirmed for ${reservedLocation.name}.',
        bookingConfirmation: UserBookingConfirmation(
          booking: booking,
          location: reservedLocation,
          ticket: ticket,
        ),
      );
      _startActiveQrUpdates(booking.id);
      _scheduleRouteRefresh(reservedLocation);
      _syncQrExpiryNotifications(ticket);
    } on Object catch (error) {
      state = state.copyWith(
        isBookingInProgress: false,
        error: FirebaseErrorMessages.friendlyMessage(error),
      );
    }
  }

  List<Booking> _mergeBooking(List<Booking> current, Booking booking) {
    final withoutExisting = current
        .where((item) => item.id != booking.id)
        .toList();
    return [booking, ...withoutExisting]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _refreshRoutesForSelected(ParkingLocation location) async {
    final origin =
        state.position?.toRoutePoint() ??
        const UserPosition(
          latitude: 13.3281211,
          longitude: 77.1256930,
          isFallback: true,
          message: 'Using SIT Tumkur fallback location.',
        ).toRoutePoint();
    final destination = _gateSelector.destinationFor(
      origin: origin,
      location: location,
    );
    final routeKey =
        '${location.id}:${origin.latitude.toStringAsFixed(4)},${origin.longitude.toStringAsFixed(4)}:${destination.latitude.toStringAsFixed(4)},${destination.longitude.toStringAsFixed(4)}';
    if (_lastRouteKey == routeKey && state.routes.isNotEmpty) {
      return;
    }
    final requestId = ++_routeRequestId;
    state = state.copyWith(isRouteLoading: true);
    try {
      final routes = await _routeProvider.findRoutes(
        origin: origin,
        destination: destination,
      );
      if (requestId != _routeRequestId ||
          state.selectedLocation?.id != location.id) {
        return;
      }
      _lastRouteKey = routeKey;
      state = state.copyWith(
        routes: routes,
        selectedRouteId: routes.firstOrNull?.id,
        clearSelectedRoute: routes.isEmpty,
        isRouteLoading: false,
      );
    } on Object catch (error) {
      debugPrint('Route calculation failed: $error');
      if (requestId != _routeRequestId) {
        return;
      }
      state = state.copyWith(
        routes: const [],
        clearSelectedRoute: true,
        isRouteLoading: false,
        actionMessage: 'Connection is slow. Retrying route when available.',
      );
    }
  }

  void _scheduleRouteRefresh(ParkingLocation location) {
    _routeDebounce?.cancel();
    _routeDebounce = Timer(const Duration(milliseconds: 420), () {
      unawaited(_refreshRoutesForSelected(location));
    });
  }

  ParkingLocation? _updatedSelectedFrom(List<ParkingLocation> locations) {
    final selectedId = state.selectedLocation?.id;
    if (selectedId == null) {
      return null;
    }
    return locations.where((location) => location.id == selectedId).firstOrNull;
  }

  List<ParkingLocation> _userVisibleParkingAreas(
    List<ParkingLocation> locations,
  ) {
    return locations
        .where((location) => location.isUserVisibleParkingArea)
        .toList();
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
    } on Object catch (error) {
      debugPrint('Cancel booking failed: $error');
      state = state.copyWith(error: 'Could not complete this action.');
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
    final activeAreaIds = locations.map((location) => location.id).toSet();
    final thumbnails = Map<String, ParkingAreaImage>.from(state.thumbnailByArea)
      ..removeWhere((areaId, _) => !activeAreaIds.contains(areaId));
    try {
      for (final location in locations.take(10)) {
        if (thumbnails.containsKey(location.id)) {
          continue;
        }
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
      debugPrint('Thumbnail load failed: $error');
      state = state.copyWith(thumbnailByArea: thumbnails);
    }
  }

  Future<void> _loadPreviewImages(ParkingLocation location) async {
    state = state.copyWith(previewImages: const []);
    final cached = _imageCache.getMany(location.imagePreviewRefs);
    if (cached.isNotEmpty &&
        cached.length == location.imagePreviewRefs.length) {
      if (state.selectedLocation?.id == location.id) {
        state = state.copyWith(previewImages: cached);
      }
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
      if (state.selectedLocation?.id == location.id) {
        state = state.copyWith(previewImages: images);
      }
    } on Object catch (error) {
      debugPrint('Preview image load failed: $error');
      state = state.copyWith(
        previewImages: const [],
        actionMessage: 'Connection is slow. Images will appear when ready.',
      );
    }
  }

  Future<void> _loadReviews(String areaId) async {
    try {
      final reviews = await _reviewRepository.getForArea(areaId, limit: 5);
      if (state.selectedLocation?.id == areaId) {
        state = state.copyWith(selectedReviews: reviews);
      }
    } on Object catch (error) {
      debugPrint('Review load failed: $error');
      state = state.copyWith(
        selectedReviews: const [],
        actionMessage: 'Unable to load comments right now.',
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
      final previous = state.position;
      if (previous != null &&
          Geolocator.distanceBetween(
                previous.latitude,
                previous.longitude,
                position.latitude,
                position.longitude,
              ) <
              50) {
        return;
      }
      state = state.copyWith(position: position);
      final selected = state.selectedLocation;
      if (selected != null) {
        _scheduleRouteRefresh(selected);
      }
    });
  }

  void _startParkingUpdates() {
    _parkingSubscription ??= _parkingRepository
        .watchOpenAreas(limit: 100)
        .listen(
          (locations) async {
            final visibleLocations = _userVisibleParkingAreas(locations);
            final updatedSelected = _updatedSelectedFrom(visibleLocations);
            // Firestore streams update the lightweight area list in place.
            // Search, filters, selected area, tab, and sheet position stay in
            // local state so realtime snapshots do not wipe the Home UX.
            state = state.copyWith(
              locations: visibleLocations,
              selectedLocation: updatedSelected,
              clearSelectedLocation:
                  state.selectedLocation != null && updatedSelected == null,
              isLoading: false,
              error: null,
            );
            if (updatedSelected != null) {
              _scheduleRouteRefresh(updatedSelected);
            }
            unawaited(_loadThumbnails(visibleLocations));
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
                .where((booking) => booking.isCurrentSession)
                .firstOrNull;
            state = state.copyWith(bookings: bookings);
            _startActiveQrUpdates(
              activeBooking == null || activeBooking.isParkingActive
                  ? null
                  : activeBooking.id,
            );
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
    if (bookingId != null &&
        _activeQrBookingId == bookingId &&
        _activeQrSubscription != null) {
      return;
    }
    _activeQrSubscription?.cancel();
    _activeQrSubscription = null;
    _activeQrBookingId = bookingId;
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
    _routeDebounce?.cancel();
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
    _activeQrBookingId = null;
    _reviewSubscription = null;
    _notificationSubscription = null;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _routeDebounce?.cancel();
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
