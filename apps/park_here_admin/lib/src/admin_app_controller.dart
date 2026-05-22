import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:park_here_shared/park_here_shared.dart';

final adminAuthProvider = Provider<AuthService>((ref) => FirebaseAuthService());
final adminParkingRepositoryProvider = Provider<ParkingRepository>(
  (ref) => FirebaseParkingRepository(),
);
final adminBookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => FirebaseBookingRepository(),
);
final adminImageRepositoryProvider = Provider<ImageRepository>(
  (ref) => FirestoreImageRepository(),
);
final adminRegionRepositoryProvider = Provider<RegionRepository>(
  (ref) => FirebaseRegionRepository(),
);
final adminIssueRepositoryProvider = Provider<IssueRepository>(
  (ref) => FirebaseIssueRepository(),
);
final adminFirebaseReadinessProvider = Provider<FirebaseReadiness>(
  (ref) => const FirebaseReadinessService().check(),
);
final adminLocationServiceProvider = Provider<AdminLocationService>(
  (ref) => GeolocatorAdminLocationService(),
);

final adminAppControllerProvider =
    StateNotifierProvider<AdminAppController, AdminAppState>((ref) {
      return AdminAppController(
        auth: ref.watch(adminAuthProvider),
        parkingRepository: ref.watch(adminParkingRepositoryProvider),
        bookingRepository: ref.watch(adminBookingRepositoryProvider),
        imageRepository: ref.watch(adminImageRepositoryProvider),
        regionRepository: ref.watch(adminRegionRepositoryProvider),
        issueRepository: ref.watch(adminIssueRepositoryProvider),
        locationService: ref.watch(adminLocationServiceProvider),
      )..load();
    });

enum AdminSection { dashboard, region, parkingAreas, bookings, issues, profile }

enum AdminAuthStatus { checking, signedOut, signedIn }

enum AdminGeometryMode { addCorner, moveCorner, addGate, moveGate }

enum AdminRegionEditMode { addPoint, movePoint }

enum AdminGeometryPointKind { corner, gate }

const Object _unset = Object();

class AdminGeometrySelection {
  const AdminGeometrySelection({required this.kind, required this.index});

  final AdminGeometryPointKind kind;
  final int index;

  String get label => kind == AdminGeometryPointKind.corner
      ? 'Corner ${index + 1}'
      : 'Gate ${index + 1}';
}

class AdminGeometrySnapshot {
  const AdminGeometrySnapshot({
    required this.boundaryPoints,
    required this.gatePoints,
    required this.message,
  });

  final List<GeoPointValue> boundaryPoints;
  final List<GatePoint> gatePoints;
  final String message;
}

class AdminGpsPosition {
  const AdminGpsPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.isFallback,
    required this.message,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final bool isFallback;
  final String message;

  GeoPointValue toGeoPoint() =>
      GeoPointValue(latitude: latitude, longitude: longitude);
}

abstract interface class AdminLocationService {
  Future<AdminGpsPosition> currentPosition();
}

class GeolocatorAdminLocationService implements AdminLocationService {
  static const _fallback = AdminGpsPosition(
    latitude: 13.3281211,
    longitude: 77.1256930,
    accuracyMeters: 999,
    isFallback: true,
    message:
        'GPS unavailable. Fallback SIT center is shown; do not save geometry until live GPS works.',
  );

  @override
  Future<AdminGpsPosition> currentPosition() async {
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
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
    return AdminGpsPosition(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      isFallback: false,
      message: position.accuracy > 25
          ? 'GPS accuracy is poor (${position.accuracy.toStringAsFixed(0)} m). Wait outdoors before saving.'
          : 'GPS accuracy ${position.accuracy.toStringAsFixed(0)} m.',
    );
  }
}

class AdminAppState {
  const AdminAppState({
    required this.admin,
    required this.authStatus,
    required this.section,
    required this.region,
    required this.hasControlledRegion,
    required this.locations,
    required this.referenceLocations,
    required this.referenceRegions,
    required this.bookings,
    required this.issues,
    required this.selectedImages,
    required this.selectedLocation,
    required this.draftBoundaryPoints,
    required this.draftGatePoints,
    required this.geometryMode,
    required this.geometryUndoStack,
    required this.regionDraftBoundaryPoints,
    required this.regionEditMode,
    required this.regionUndoStack,
    required this.isSavingRegion,
    required this.regionStatusMessage,
    required this.isSavingGeometry,
    required this.lastGpsPosition,
    required this.isLoading,
    required this.imageUploadProgress,
    required this.imageStatusMessage,
    required this.geometryStatusMessage,
    this.selectedGeometryPoint,
    this.selectedRegionPoint,
    this.error,
  });

  factory AdminAppState.initial(AdminProfile admin) {
    return AdminAppState(
      admin: admin,
      authStatus: AdminAuthStatus.checking,
      section: AdminSection.dashboard,
      region: _emptyRegionForAdmin(admin.id),
      hasControlledRegion: false,
      locations: const [],
      referenceLocations: const [],
      referenceRegions: const [],
      bookings: const [],
      issues: const [],
      selectedImages: const [],
      selectedLocation: null,
      draftBoundaryPoints: const [],
      draftGatePoints: const [],
      geometryMode: AdminGeometryMode.addCorner,
      selectedGeometryPoint: null,
      geometryUndoStack: const [],
      regionDraftBoundaryPoints: const [],
      regionEditMode: AdminRegionEditMode.addPoint,
      selectedRegionPoint: null,
      regionUndoStack: const [],
      isSavingRegion: false,
      regionStatusMessage: 'Add at least 3 points to define your region.',
      isSavingGeometry: false,
      lastGpsPosition: null,
      isLoading: true,
      imageUploadProgress: 0,
      imageStatusMessage: 'Images are optimized before Firestore upload.',
      geometryStatusMessage:
          'Stand at the real corner or gate, then mark current GPS.',
    );
  }

  factory AdminAppState.signedOut() {
    return AdminAppState(
      admin: null,
      authStatus: AdminAuthStatus.signedOut,
      section: AdminSection.dashboard,
      region: _emptyRegionForAdmin(''),
      hasControlledRegion: false,
      locations: const [],
      referenceLocations: const [],
      referenceRegions: const [],
      bookings: const [],
      issues: const [],
      selectedImages: const [],
      selectedLocation: null,
      draftBoundaryPoints: const [],
      draftGatePoints: const [],
      geometryMode: AdminGeometryMode.addCorner,
      selectedGeometryPoint: null,
      geometryUndoStack: const [],
      regionDraftBoundaryPoints: const [],
      regionEditMode: AdminRegionEditMode.addPoint,
      selectedRegionPoint: null,
      regionUndoStack: const [],
      isSavingRegion: false,
      regionStatusMessage: 'Sign in to set up your controlled region.',
      isSavingGeometry: false,
      lastGpsPosition: null,
      isLoading: false,
      imageUploadProgress: 0,
      imageStatusMessage: 'Sign in to manage Firebase image records.',
      geometryStatusMessage: 'Sign in to mark parking area geometry.',
    );
  }

  final AdminProfile? admin;
  final AdminAuthStatus authStatus;
  final AdminSection section;
  final ParkingRegion region;
  final bool hasControlledRegion;
  final List<ParkingLocation> locations;
  final List<ParkingLocation> referenceLocations;
  final List<ParkingRegion> referenceRegions;
  final List<Booking> bookings;
  final List<IssueReport> issues;
  final List<ParkingAreaImage> selectedImages;
  final ParkingLocation? selectedLocation;
  final List<GeoPointValue> draftBoundaryPoints;
  final List<GatePoint> draftGatePoints;
  final AdminGeometryMode geometryMode;
  final AdminGeometrySelection? selectedGeometryPoint;
  final List<AdminGeometrySnapshot> geometryUndoStack;
  final List<GeoPointValue> regionDraftBoundaryPoints;
  final AdminRegionEditMode regionEditMode;
  final int? selectedRegionPoint;
  final List<List<GeoPointValue>> regionUndoStack;
  final bool isSavingRegion;
  final String regionStatusMessage;
  final bool isSavingGeometry;
  final AdminGpsPosition? lastGpsPosition;
  final bool isLoading;
  final double imageUploadProgress;
  final String imageStatusMessage;
  final String geometryStatusMessage;
  final String? error;

  bool get requiresRegionSetup =>
      authStatus == AdminAuthStatus.signedIn && !hasControlledRegion;

  static ParkingRegion _emptyRegionForAdmin(String adminId) => ParkingRegion(
    regionId: adminId.isEmpty ? 'region_pending' : 'region_$adminId',
    name: '',
    address: '',
    boundaryPoints: const [],
    centerLat: 0,
    centerLng: 0,
    createdByAdminId: adminId,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

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

  ParkingAreaConflict? get draftAreaConflict {
    final location = selectedLocation;
    if (location == null || draftBoundaryPoints.length < 3) {
      return null;
    }
    final center = GeometryUtils.calculatePolygonCenter(draftBoundaryPoints);
    final candidate = location.copyWith(
      boundaryPoints: draftBoundaryPoints,
      gatePoints: draftGatePoints,
      latitude: center.latitude,
      longitude: center.longitude,
    );
    return GeometryUtils.validateAreaDoesNotConflict(
      candidate,
      referenceLocations,
    );
  }

  ParkingRegionConflict? get draftRegionConflict {
    if (regionDraftBoundaryPoints.length < 3) {
      return null;
    }
    final center = GeometryUtils.calculatePolygonCenter(
      regionDraftBoundaryPoints,
    );
    final candidate = region.copyWith(
      boundaryPoints: regionDraftBoundaryPoints,
      centerLat: center.latitude,
      centerLng: center.longitude,
    );
    return GeometryUtils.validateRegionDoesNotConflict(
      candidate,
      referenceRegions,
    );
  }

  AdminAppState copyWith({
    AdminProfile? admin,
    AdminAuthStatus? authStatus,
    AdminSection? section,
    ParkingRegion? region,
    bool? hasControlledRegion,
    List<ParkingLocation>? locations,
    List<ParkingLocation>? referenceLocations,
    List<ParkingRegion>? referenceRegions,
    List<Booking>? bookings,
    List<IssueReport>? issues,
    List<ParkingAreaImage>? selectedImages,
    Object? selectedLocation = _unset,
    List<GeoPointValue>? draftBoundaryPoints,
    List<GatePoint>? draftGatePoints,
    AdminGeometryMode? geometryMode,
    Object? selectedGeometryPoint = _unset,
    List<AdminGeometrySnapshot>? geometryUndoStack,
    List<GeoPointValue>? regionDraftBoundaryPoints,
    AdminRegionEditMode? regionEditMode,
    Object? selectedRegionPoint = _unset,
    List<List<GeoPointValue>>? regionUndoStack,
    bool? isSavingRegion,
    String? regionStatusMessage,
    bool? isSavingGeometry,
    AdminGpsPosition? lastGpsPosition,
    bool? isLoading,
    double? imageUploadProgress,
    String? imageStatusMessage,
    String? geometryStatusMessage,
    Object? error = _unset,
  }) {
    return AdminAppState(
      admin: admin ?? this.admin,
      authStatus: authStatus ?? this.authStatus,
      section: section ?? this.section,
      region: region ?? this.region,
      hasControlledRegion: hasControlledRegion ?? this.hasControlledRegion,
      locations: locations ?? this.locations,
      referenceLocations: referenceLocations ?? this.referenceLocations,
      referenceRegions: referenceRegions ?? this.referenceRegions,
      bookings: bookings ?? this.bookings,
      issues: issues ?? this.issues,
      selectedImages: selectedImages ?? this.selectedImages,
      selectedLocation: identical(selectedLocation, _unset)
          ? this.selectedLocation
          : selectedLocation as ParkingLocation?,
      draftBoundaryPoints: draftBoundaryPoints ?? this.draftBoundaryPoints,
      draftGatePoints: draftGatePoints ?? this.draftGatePoints,
      geometryMode: geometryMode ?? this.geometryMode,
      selectedGeometryPoint: identical(selectedGeometryPoint, _unset)
          ? this.selectedGeometryPoint
          : selectedGeometryPoint as AdminGeometrySelection?,
      geometryUndoStack: geometryUndoStack ?? this.geometryUndoStack,
      regionDraftBoundaryPoints:
          regionDraftBoundaryPoints ?? this.regionDraftBoundaryPoints,
      regionEditMode: regionEditMode ?? this.regionEditMode,
      selectedRegionPoint: identical(selectedRegionPoint, _unset)
          ? this.selectedRegionPoint
          : selectedRegionPoint as int?,
      regionUndoStack: regionUndoStack ?? this.regionUndoStack,
      isSavingRegion: isSavingRegion ?? this.isSavingRegion,
      regionStatusMessage: regionStatusMessage ?? this.regionStatusMessage,
      isSavingGeometry: isSavingGeometry ?? this.isSavingGeometry,
      lastGpsPosition: lastGpsPosition ?? this.lastGpsPosition,
      isLoading: isLoading ?? this.isLoading,
      imageUploadProgress: imageUploadProgress ?? this.imageUploadProgress,
      imageStatusMessage: imageStatusMessage ?? this.imageStatusMessage,
      geometryStatusMessage:
          geometryStatusMessage ?? this.geometryStatusMessage,
      error: identical(error, _unset) ? this.error : error?.toString(),
    );
  }
}

class AdminAppController extends StateNotifier<AdminAppState> {
  AdminAppController({
    required AuthService auth,
    required ParkingRepository parkingRepository,
    required BookingRepository bookingRepository,
    required ImageRepository imageRepository,
    required RegionRepository regionRepository,
    required IssueRepository issueRepository,
    required AdminLocationService locationService,
  }) : _auth = auth,
       _parkingRepository = parkingRepository,
       _bookingRepository = bookingRepository,
       _imageRepository = imageRepository,
       _regionRepository = regionRepository,
       _issueRepository = issueRepository,
       _locationService = locationService,
       super(AdminAppState.signedOut());

  final AuthService _auth;
  final ParkingRepository _parkingRepository;
  final BookingRepository _bookingRepository;
  final ImageRepository _imageRepository;
  final RegionRepository _regionRepository;
  final IssueRepository _issueRepository;
  final AdminLocationService _locationService;
  StreamSubscription<List<ParkingLocation>>? _parkingSubscription;
  StreamSubscription<List<ParkingLocation>>? _referenceParkingSubscription;
  StreamSubscription<List<ParkingRegion>>? _referenceRegionSubscription;
  StreamSubscription<List<Booking>>? _bookingSubscription;
  StreamSubscription<List<IssueReport>>? _issueSubscription;

  Future<void> load() async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      regionStatusMessage: 'Restoring admin workspace...',
    );
    final loadedAdmin = await _auth.loadCurrentAdmin();
    if (loadedAdmin == null) {
      state = AdminAppState.signedOut();
      return;
    }
    var admin = loadedAdmin;
    await _resetRealtimeListeners();
    var region = state.region;
    var locations = state.locations;
    var referenceLocations = state.referenceLocations;
    var referenceRegions = state.referenceRegions;
    var bookings = state.bookings;
    var issues = state.issues;
    try {
      final controlledRegion = await _resolveControlledRegion(admin);
      if (controlledRegion == null) {
        _startReferenceRegionUpdates(admin.id);
        referenceRegions = (await _regionRepository.getAllRegions())
            .where((region) => region.createdByAdminId != admin.id)
            .toList();
        state = state.copyWith(
          admin: admin,
          authStatus: AdminAuthStatus.signedIn,
          region: AdminAppState._emptyRegionForAdmin(admin.id),
          hasControlledRegion: false,
          locations: const [],
          referenceLocations: const [],
          referenceRegions: referenceRegions,
          bookings: const [],
          issues: const [],
          selectedLocation: null,
          draftBoundaryPoints: const [],
          draftGatePoints: const [],
          regionDraftBoundaryPoints: const [],
          selectedGeometryPoint: null,
          selectedRegionPoint: null,
          geometryUndoStack: const [],
          regionUndoStack: const [],
          isLoading: false,
          error: null,
          regionStatusMessage:
              'Set up your controlled region before opening the dashboard.',
        );
        return;
      }

      region = controlledRegion;
      if (admin.regionId != region.regionId || !admin.onboardingCompleted) {
        admin = await _auth.saveAdminProfile(
          admin.copyWith(regionId: region.regionId, onboardingCompleted: true),
        );
      }
      _startRealtimeListeners(admin.id);
      referenceRegions = (await _regionRepository.getAllRegions())
          .where((region) => region.createdByAdminId != admin.id)
          .toList();
      referenceLocations = await _parkingRepository.getAllAreas(limit: 500);
      locations = (await _parkingRepository.getByAdmin(
        admin.id,
      )).where((location) => location.regionId == region.regionId).toList();
      bookings = await _bookingRepository.getForAdmin(admin.id);
      issues = await _issueRepository.getForAdmin(admin.id);
      final selectedLocation = locations.firstOrNull;
      state = state.copyWith(
        admin: admin,
        authStatus: AdminAuthStatus.signedIn,
        region: region,
        hasControlledRegion: true,
        locations: locations,
        referenceLocations: referenceLocations,
        referenceRegions: referenceRegions,
        bookings: bookings,
        issues: issues,
        selectedLocation: selectedLocation,
        draftBoundaryPoints: selectedLocation?.boundaryPoints ?? const [],
        draftGatePoints: selectedLocation?.gatePoints ?? const [],
        regionDraftBoundaryPoints: region.boundaryPoints,
        selectedGeometryPoint: null,
        selectedRegionPoint: null,
        geometryUndoStack: const [],
        regionUndoStack: const [],
        isLoading: false,
        error: null,
        regionStatusMessage:
            'Region loaded with ${region.boundaryPoints.length} points.',
      );
      await _loadSelectedImages();
    } on Object catch (error) {
      state = state.copyWith(
        admin: admin,
        authStatus: AdminAuthStatus.signedIn,
        region: region,
        hasControlledRegion: region.createdByAdminId == admin.id,
        locations: locations,
        referenceLocations: referenceLocations,
        referenceRegions: referenceRegions,
        bookings: bookings,
        issues: issues,
        isLoading: false,
        error: FirebaseErrorMessages.friendlyMessage(error),
      );
    }
  }

  Future<ParkingRegion?> _resolveControlledRegion(AdminProfile admin) async {
    final assignedRegionId = admin.regionId;
    if (assignedRegionId != null && assignedRegionId.trim().isNotEmpty) {
      final assignedRegion = await _regionRepository.findById(assignedRegionId);
      if (assignedRegion != null &&
          assignedRegion.createdByAdminId == admin.id) {
        return assignedRegion;
      }
    }
    return _regionRepository.getControlledRegion(admin.id);
  }

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _auth.signInAdminWithEmail(email: email, password: password);
      await load();
    } on Object catch (error) {
      state = AdminAppState.signedOut().copyWith(error: error.toString());
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String businessName,
    required String ownerName,
    required String phone,
    String? upiId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _auth.signUpAdminWithEmail(
        email: email,
        password: password,
        businessName: businessName,
        ownerName: ownerName,
        phone: phone,
        upiId: upiId,
      );
      await load();
    } on Object catch (error) {
      state = AdminAppState.signedOut().copyWith(error: error.toString());
    }
  }

  Future<void> signOut() async {
    await _resetRealtimeListeners();
    await _auth.signOut();
    state = AdminAppState.signedOut();
  }

  void changeSection(AdminSection section) {
    state = state.copyWith(section: section);
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
    state = state.copyWith(admin: admin, authStatus: AdminAuthStatus.signedIn);
    await load();
  }

  Future<void> selectLocation(ParkingLocation location) async {
    state = state.copyWith(
      selectedLocation: location,
      draftBoundaryPoints: location.boundaryPoints,
      draftGatePoints: location.gatePoints,
      selectedGeometryPoint: null,
      geometryUndoStack: const [],
      geometryStatusMessage:
          'Loaded ${location.boundaryPoints.length} corners and ${location.gatePoints.length} gates.',
    );
    await _loadSelectedImages();
  }

  void changeRegionEditMode(AdminRegionEditMode mode) {
    state = state.copyWith(
      regionEditMode: mode,
      selectedRegionPoint: null,
      regionStatusMessage: mode == AdminRegionEditMode.addPoint
          ? 'Add Point mode active. Tap the map to add region corners.'
          : 'Move Point mode active. Select a point, then tap its new location.',
      error: null,
    );
  }

  void handleRegionMapTap(GeoPointValue point) {
    if (state.regionEditMode == AdminRegionEditMode.movePoint) {
      final selected = state.selectedRegionPoint;
      if (selected == null) {
        state = state.copyWith(
          regionStatusMessage:
              'Move Point mode active. Select an existing region point first.',
        );
        return;
      }
      moveSelectedRegionPoint(point);
      return;
    }
    addRegionPoint(point);
  }

  void addRegionPoint(GeoPointValue point) {
    _pushRegionUndo();
    final updated = [...state.regionDraftBoundaryPoints, point];
    state = state.copyWith(
      regionDraftBoundaryPoints: updated,
      selectedRegionPoint: updated.length - 1,
      regionStatusMessage: 'Added region point ${updated.length}.',
      error: null,
    );
  }

  void selectRegionPoint(int index) {
    if (index < 0 || index >= state.regionDraftBoundaryPoints.length) {
      return;
    }
    state = state.copyWith(
      selectedRegionPoint: index,
      regionEditMode: AdminRegionEditMode.movePoint,
      regionStatusMessage:
          'Selected region point ${index + 1}. Tap the map to move it.',
      error: null,
    );
  }

  void moveSelectedRegionPoint(GeoPointValue point) {
    final selected = state.selectedRegionPoint;
    if (selected == null ||
        selected < 0 ||
        selected >= state.regionDraftBoundaryPoints.length) {
      state = state.copyWith(error: 'Select a region point first.');
      return;
    }
    _pushRegionUndo();
    final updated = [...state.regionDraftBoundaryPoints];
    updated[selected] = point;
    state = state.copyWith(
      regionDraftBoundaryPoints: updated,
      regionStatusMessage: 'Moved region point ${selected + 1}.',
      error: null,
    );
  }

  Future<void> markCurrentPositionAsRegionPoint() async {
    final position = await _locationService.currentPosition();
    if (position.isFallback) {
      state = state.copyWith(
        lastGpsPosition: position,
        error: 'GPS fallback cannot mark a controlled region.',
      );
      return;
    }
    addRegionPoint(position.toGeoPoint());
    state = state.copyWith(
      lastGpsPosition: position,
      regionStatusMessage:
          'Added GPS region point ${state.regionDraftBoundaryPoints.length}. ${position.message}',
    );
  }

  void undoLastRegionPoint() {
    if (state.regionDraftBoundaryPoints.isEmpty) {
      return;
    }
    _pushRegionUndo();
    final updated = state.regionDraftBoundaryPoints
        .take(state.regionDraftBoundaryPoints.length - 1)
        .toList();
    state = state.copyWith(
      regionDraftBoundaryPoints: updated,
      selectedRegionPoint: null,
      regionStatusMessage: 'Removed last region point.',
    );
  }

  void clearRegionDraft() {
    if (state.regionDraftBoundaryPoints.isEmpty) {
      return;
    }
    _pushRegionUndo();
    state = state.copyWith(
      regionDraftBoundaryPoints: const [],
      selectedRegionPoint: null,
      regionStatusMessage: 'Cleared region draft.',
    );
  }

  void undoLastRegionChange() {
    if (state.regionUndoStack.isEmpty) {
      state = state.copyWith(regionStatusMessage: 'Nothing to undo.');
      return;
    }
    final stack = [...state.regionUndoStack];
    final previous = stack.removeLast();
    state = state.copyWith(
      regionDraftBoundaryPoints: previous,
      selectedRegionPoint: null,
      regionUndoStack: stack,
      regionStatusMessage: 'Undid last region edit.',
      error: null,
    );
  }

  Future<void> saveControlledRegion({
    required String name,
    required String address,
  }) async {
    final admin = state.admin;
    if (admin == null) {
      state = state.copyWith(error: 'Sign in before saving a region.');
      return;
    }
    final cleanName = name.trim();
    final cleanAddress = address.trim();
    if (cleanName.isEmpty) {
      state = state.copyWith(error: 'Enter a region name.');
      return;
    }
    if (cleanAddress.isEmpty) {
      state = state.copyWith(error: 'Enter a region address.');
      return;
    }
    if (state.regionDraftBoundaryPoints.length < 3) {
      state = state.copyWith(
        error: 'Region polygon must have at least 3 points.',
      );
      return;
    }
    final center = GeometryUtils.calculatePolygonCenter(
      state.regionDraftBoundaryPoints,
    );
    if (!GeometryUtils.pointInPolygon(
      center,
      state.regionDraftBoundaryPoints,
    )) {
      state = state.copyWith(error: 'Region area cannot be empty.');
      return;
    }
    final draftConflict = state.draftRegionConflict;
    if (draftConflict != null) {
      state = state.copyWith(error: draftConflict.message);
      return;
    }
    state = state.copyWith(isSavingRegion: true, error: null);
    try {
      final now = DateTime.now();
      final existing = state.hasControlledRegion ? state.region : null;
      final region = ParkingRegion(
        regionId: existing?.regionId ?? 'region_${admin.id}',
        name: cleanName,
        address: cleanAddress,
        boundaryPoints: state.regionDraftBoundaryPoints,
        centerLat: center.latitude,
        centerLng: center.longitude,
        createdByAdminId: admin.id,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      await _regionRepository.upsertRegion(region);
      final updatedAdmin = await _auth.saveAdminProfile(
        admin.copyWith(regionId: region.regionId, onboardingCompleted: true),
      );
      state = state.copyWith(
        admin: updatedAdmin,
        region: region,
        hasControlledRegion: true,
        regionDraftBoundaryPoints: region.boundaryPoints,
        selectedRegionPoint: null,
        regionUndoStack: const [],
        isSavingRegion: false,
        regionStatusMessage: 'Controlled region saved.',
        section: AdminSection.dashboard,
        error: null,
      );
      await load();
    } on Object catch (error) {
      state = state.copyWith(
        isSavingRegion: false,
        error: FirebaseErrorMessages.friendlyMessage(error),
      );
    }
  }

  void _pushRegionUndo() {
    final next = [
      ...state.regionUndoStack,
      List<GeoPointValue>.unmodifiable(state.regionDraftBoundaryPoints),
    ];
    state = state.copyWith(
      regionUndoStack: next.length > 20 ? next.sublist(next.length - 20) : next,
    );
  }

  Future<void> updateSelectedAreaBoundary(List<GeoPointValue> points) async {
    final location = state.selectedLocation;
    if (location == null) {
      return;
    }
    final updated = location.copyWith(
      boundaryPoints: points,
      updatedAt: DateTime.now(),
    );
    await _parkingRepository.upsert(updated);
    state = state.copyWith(selectedLocation: updated);
    await load();
  }

  Future<void> nudgeSelectedAreaBoundary() async {
    final location = state.selectedLocation;
    if (location == null) {
      return;
    }
    final source = location.boundaryPoints.isEmpty
        ? state.region.boundaryPoints
        : location.boundaryPoints;
    final updated = source
        .map(
          (point) => GeoPointValue(
            latitude: point.latitude,
            longitude: point.longitude + 0.0001,
          ),
        )
        .toList();
    await updateSelectedAreaBoundary(updated);
  }

  void changeGeometryMode(AdminGeometryMode mode) {
    state = state.copyWith(
      geometryMode: mode,
      selectedGeometryPoint: null,
      geometryStatusMessage: switch (mode) {
        AdminGeometryMode.addCorner =>
          'Add Corner mode active. Tap inside your region to add area corners.',
        AdminGeometryMode.moveCorner =>
          'Move Corner mode active. Select a corner, then tap its new location.',
        AdminGeometryMode.addGate =>
          'Add Gate mode active. Tap inside your region to add a gate.',
        AdminGeometryMode.moveGate =>
          'Move Gate mode active. Select a gate, then tap its new location.',
      },
    );
  }

  void selectCornerPoint(int index) {
    if (index < 0 || index >= state.draftBoundaryPoints.length) {
      return;
    }
    state = state.copyWith(
      selectedGeometryPoint: AdminGeometrySelection(
        kind: AdminGeometryPointKind.corner,
        index: index,
      ),
      geometryStatusMessage:
          'Selected corner ${index + 1}. Tap another map position to move it.',
      error: null,
    );
  }

  void selectGatePoint(int index) {
    if (index < 0 || index >= state.draftGatePoints.length) {
      return;
    }
    state = state.copyWith(
      selectedGeometryPoint: AdminGeometrySelection(
        kind: AdminGeometryPointKind.gate,
        index: index,
      ),
      geometryStatusMessage:
          'Selected ${state.draftGatePoints[index].name}. Tap another map position to move it.',
      error: null,
    );
  }

  void clearGeometrySelection() {
    state = state.copyWith(
      selectedGeometryPoint: null,
      geometryStatusMessage: 'Selection cleared.',
    );
  }

  void handleMapTap(GeoPointValue point) {
    if (state.selectedLocation == null) {
      state = state.copyWith(error: 'Select a parking area first.');
      return;
    }
    if (!_isInsideControlledRegion(point)) {
      state = state.copyWith(
        error: 'Parking area must be inside your controlled region.',
      );
      return;
    }
    final selected = state.selectedGeometryPoint;
    if (selected != null &&
        (state.geometryMode == AdminGeometryMode.moveCorner ||
            state.geometryMode == AdminGeometryMode.moveGate)) {
      moveSelectedGeometryPoint(point);
      return;
    }
    if (state.geometryMode == AdminGeometryMode.moveCorner ||
        state.geometryMode == AdminGeometryMode.moveGate) {
      state = state.copyWith(error: 'Select a point to move first.');
      return;
    }
    if (state.geometryMode == AdminGeometryMode.addCorner) {
      addCornerPoint(point);
    } else {
      addGatePoint(point);
    }
  }

  void addCornerPoint(GeoPointValue point) {
    if (!_isInsideControlledRegion(point)) {
      state = state.copyWith(
        error: 'Parking area must be inside your controlled region.',
      );
      return;
    }
    _pushGeometryUndo('Undo add corner');
    final updated = [...state.draftBoundaryPoints, point];
    state = state.copyWith(
      draftBoundaryPoints: updated,
      selectedGeometryPoint: AdminGeometrySelection(
        kind: AdminGeometryPointKind.corner,
        index: updated.length - 1,
      ),
      geometryStatusMessage:
          'Added corner ${updated.length}. Tap another point to move the selected corner, or clear selection to add more.',
      error: null,
    );
  }

  void addGatePoint(
    GeoPointValue point, {
    String name = 'Gate',
    GatePointType type = GatePointType.both,
  }) {
    final location = state.selectedLocation;
    if (location == null) {
      state = state.copyWith(error: 'Select a parking area first.');
      return;
    }
    if (!_isInsideControlledRegion(point)) {
      state = state.copyWith(
        error: 'Gate must be inside your controlled region.',
      );
      return;
    }
    _pushGeometryUndo('Undo add gate');
    final gateIndex = state.draftGatePoints.length + 1;
    final gate = GatePoint(
      gateId: 'gate_${location.id}_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty || name == 'Gate'
          ? 'Gate $gateIndex'
          : name.trim(),
      latitude: point.latitude,
      longitude: point.longitude,
      type: type,
      createdAt: DateTime.now(),
    );
    final updated = [...state.draftGatePoints, gate];
    state = state.copyWith(
      draftGatePoints: updated,
      selectedGeometryPoint: AdminGeometrySelection(
        kind: AdminGeometryPointKind.gate,
        index: updated.length - 1,
      ),
      geometryStatusMessage:
          'Added ${gate.name}. Select the gate below to rename/type it.',
      error: null,
    );
  }

  void moveSelectedGeometryPoint(GeoPointValue point) {
    if (!_isInsideControlledRegion(point)) {
      state = state.copyWith(
        error: 'Parking area must be inside your controlled region.',
      );
      return;
    }
    final selected = state.selectedGeometryPoint;
    if (selected == null) {
      state = state.copyWith(error: 'Select a corner or gate first.');
      return;
    }
    if (selected.kind == AdminGeometryPointKind.corner) {
      if (selected.index >= state.draftBoundaryPoints.length) {
        state = state.copyWith(selectedGeometryPoint: null);
        return;
      }
      _pushGeometryUndo('Undo move corner');
      final updated = [...state.draftBoundaryPoints];
      updated[selected.index] = point;
      state = state.copyWith(
        draftBoundaryPoints: updated,
        geometryStatusMessage: 'Moved corner ${selected.index + 1}.',
        error: null,
      );
      return;
    }
    if (selected.index >= state.draftGatePoints.length) {
      state = state.copyWith(selectedGeometryPoint: null);
      return;
    }
    _pushGeometryUndo('Undo move gate');
    final updated = [...state.draftGatePoints];
    final gate = updated[selected.index];
    updated[selected.index] = gate.copyWith(
      latitude: point.latitude,
      longitude: point.longitude,
    );
    state = state.copyWith(
      draftGatePoints: updated,
      geometryStatusMessage: 'Moved ${gate.name}.',
      error: null,
    );
  }

  void deleteSelectedGeometryPoint() {
    final selected = state.selectedGeometryPoint;
    if (selected == null) {
      state = state.copyWith(error: 'Select a point to delete.');
      return;
    }
    if (selected.kind == AdminGeometryPointKind.corner) {
      if (selected.index >= state.draftBoundaryPoints.length) {
        state = state.copyWith(selectedGeometryPoint: null);
        return;
      }
      _pushGeometryUndo('Undo delete corner');
      final updated = [...state.draftBoundaryPoints]..removeAt(selected.index);
      state = state.copyWith(
        draftBoundaryPoints: updated,
        selectedGeometryPoint: null,
        geometryStatusMessage: 'Deleted corner ${selected.index + 1}.',
        error: null,
      );
      return;
    }
    removeGateAt(selected.index);
  }

  void removeGateAt(int index) {
    if (index < 0 || index >= state.draftGatePoints.length) {
      return;
    }
    _pushGeometryUndo('Undo delete gate');
    final gate = state.draftGatePoints[index];
    final updated = [...state.draftGatePoints]..removeAt(index);
    state = state.copyWith(
      draftGatePoints: updated,
      selectedGeometryPoint: null,
      geometryStatusMessage: 'Removed ${gate.name}.',
      error: null,
    );
  }

  void updateGatePoint({
    required int index,
    required String name,
    required GatePointType type,
  }) {
    if (index < 0 || index >= state.draftGatePoints.length) {
      return;
    }
    _pushGeometryUndo('Undo edit gate');
    final updated = [...state.draftGatePoints];
    updated[index] = updated[index].copyWith(
      name: name.trim().isEmpty ? updated[index].name : name.trim(),
      type: type,
    );
    state = state.copyWith(
      draftGatePoints: updated,
      selectedGeometryPoint: AdminGeometrySelection(
        kind: AdminGeometryPointKind.gate,
        index: index,
      ),
      geometryStatusMessage: 'Updated ${updated[index].name}.',
      error: null,
    );
  }

  Future<void> markCurrentPositionAsCorner() async {
    final location = state.selectedLocation;
    if (location == null) {
      state = state.copyWith(error: 'Select a parking area first.');
      return;
    }
    final position = await _locationService.currentPosition();
    if (position.isFallback) {
      state = state.copyWith(
        lastGpsPosition: position,
        error: 'GPS fallback cannot mark real geometry. Enable location first.',
      );
      return;
    }
    if (!_isInsideControlledRegion(position.toGeoPoint())) {
      state = state.copyWith(
        lastGpsPosition: position,
        error: 'Parking area must be inside your controlled region.',
      );
      return;
    }
    _pushGeometryUndo('Undo GPS corner');
    final updated = [...state.draftBoundaryPoints, position.toGeoPoint()];
    state = state.copyWith(
      draftBoundaryPoints: updated,
      selectedGeometryPoint: AdminGeometrySelection(
        kind: AdminGeometryPointKind.corner,
        index: updated.length - 1,
      ),
      lastGpsPosition: position,
      geometryStatusMessage:
          'Added corner ${updated.length}. ${position.message}',
      error: null,
    );
  }

  Future<void> markCurrentPositionAsGate({
    String name = 'Gate',
    GatePointType type = GatePointType.both,
  }) async {
    final location = state.selectedLocation;
    if (location == null) {
      state = state.copyWith(error: 'Select a parking area first.');
      return;
    }
    final position = await _locationService.currentPosition();
    if (position.isFallback) {
      state = state.copyWith(
        lastGpsPosition: position,
        error: 'GPS fallback cannot mark real gates. Enable location first.',
      );
      return;
    }
    if (!_isInsideControlledRegion(position.toGeoPoint())) {
      state = state.copyWith(
        lastGpsPosition: position,
        error: 'Gate must be inside your controlled region.',
      );
      return;
    }
    _pushGeometryUndo('Undo GPS gate');
    final gateIndex = state.draftGatePoints.length + 1;
    final gate = GatePoint(
      gateId: 'gate_${location.id}_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Gate $gateIndex' : name.trim(),
      latitude: position.latitude,
      longitude: position.longitude,
      type: type,
      createdAt: DateTime.now(),
    );
    final updated = [...state.draftGatePoints, gate];
    state = state.copyWith(
      draftGatePoints: updated,
      selectedGeometryPoint: AdminGeometrySelection(
        kind: AdminGeometryPointKind.gate,
        index: updated.length - 1,
      ),
      lastGpsPosition: position,
      geometryStatusMessage: 'Added ${gate.name}. ${position.message}',
      error: null,
    );
  }

  void undoLastCorner() {
    if (state.draftBoundaryPoints.isEmpty) {
      return;
    }
    _pushGeometryUndo('Undo remove corner');
    final updated = state.draftBoundaryPoints
        .take(state.draftBoundaryPoints.length - 1)
        .toList();
    state = state.copyWith(
      draftBoundaryPoints: updated,
      selectedGeometryPoint: null,
      geometryStatusMessage: 'Removed last corner.',
    );
  }

  void undoLastGate() {
    if (state.draftGatePoints.isEmpty) {
      return;
    }
    _pushGeometryUndo('Undo remove gate');
    final updated = state.draftGatePoints
        .take(state.draftGatePoints.length - 1)
        .toList();
    state = state.copyWith(
      draftGatePoints: updated,
      selectedGeometryPoint: null,
      geometryStatusMessage: 'Removed last gate.',
    );
  }

  void clearCorners() {
    if (state.draftBoundaryPoints.isEmpty) {
      return;
    }
    _pushGeometryUndo('Undo clear corners');
    state = state.copyWith(
      draftBoundaryPoints: const [],
      selectedGeometryPoint: null,
      geometryStatusMessage: 'Cleared draft corner points.',
    );
  }

  void clearGates() {
    if (state.draftGatePoints.isEmpty) {
      return;
    }
    _pushGeometryUndo('Undo clear gates');
    state = state.copyWith(
      draftGatePoints: const [],
      selectedGeometryPoint: null,
      geometryStatusMessage: 'Cleared draft gate points.',
    );
  }

  void undoLastGeometryChange() {
    if (state.geometryUndoStack.isEmpty) {
      state = state.copyWith(geometryStatusMessage: 'Nothing to undo.');
      return;
    }
    final stack = [...state.geometryUndoStack];
    final snapshot = stack.removeLast();
    state = state.copyWith(
      draftBoundaryPoints: snapshot.boundaryPoints,
      draftGatePoints: snapshot.gatePoints,
      selectedGeometryPoint: null,
      geometryUndoStack: stack,
      geometryStatusMessage: snapshot.message,
      error: null,
    );
  }

  void _pushGeometryUndo(String message) {
    final next = [
      ...state.geometryUndoStack,
      AdminGeometrySnapshot(
        boundaryPoints: List<GeoPointValue>.unmodifiable(
          state.draftBoundaryPoints,
        ),
        gatePoints: List<GatePoint>.unmodifiable(state.draftGatePoints),
        message: message,
      ),
    ];
    state = state.copyWith(
      geometryUndoStack: next.length > 20
          ? next.sublist(next.length - 20)
          : next,
    );
  }

  Future<void> saveAreaGeometry() async {
    final location = state.selectedLocation;
    if (location == null) {
      state = state.copyWith(error: 'Select a parking area first.');
      return;
    }
    final validationError = _validateAreaForSave(location);
    if (validationError != null) {
      state = state.copyWith(error: validationError);
      return;
    }
    if (state.draftBoundaryPoints.length < 3) {
      state = state.copyWith(
        error: 'Mark at least 3 corner points before saving geometry.',
      );
      return;
    }
    state = state.copyWith(isSavingGeometry: true, error: null);
    try {
      final center = GeometryUtils.calculatePolygonCenter(
        state.draftBoundaryPoints,
      );
      final updated = location.copyWith(
        boundaryPoints: state.draftBoundaryPoints,
        gatePoints: state.draftGatePoints,
        latitude: center.latitude,
        longitude: center.longitude,
        updatedAt: DateTime.now(),
      );
      await _parkingRepository.upsert(updated);
      state = state.copyWith(
        selectedLocation: updated,
        isSavingGeometry: false,
        selectedGeometryPoint: null,
        geometryUndoStack: const [],
        geometryStatusMessage:
            'Saved ${updated.boundaryPoints.length} corners and ${updated.gatePoints.length} gates.',
        error: null,
      );
      await load();
      final refreshed = await _parkingRepository.findById(updated.id);
      if (refreshed != null) {
        state = state.copyWith(
          selectedLocation: refreshed,
          draftBoundaryPoints: refreshed.boundaryPoints,
          draftGatePoints: refreshed.gatePoints,
          isSavingGeometry: false,
        );
      }
    } on Object catch (error) {
      state = state.copyWith(
        isSavingGeometry: false,
        error: FirebaseErrorMessages.friendlyMessage(error),
      );
    }
  }

  Future<void> registerLocation({
    required String name,
    required String description,
    required String address,
    required int totalSpaces,
    required int availableSpaces,
    required double pricePerHour,
    required List<VehicleType> vehicleTypes,
    required String openingTime,
    required String closingTime,
  }) async {
    if (!state.hasControlledRegion) {
      state = state.copyWith(error: 'Set up your controlled region first.');
      return;
    }
    if (name.trim().isEmpty) {
      state = state.copyWith(error: 'Parking area name is required.');
      return;
    }
    if (address.trim().isEmpty) {
      state = state.copyWith(error: 'Parking area address is required.');
      return;
    }
    final spaceError = _validateSpaces(
      totalSpaces: totalSpaces,
      availableSpaces: availableSpaces,
    );
    if (spaceError != null) {
      state = state.copyWith(error: spaceError);
      return;
    }
    if (!ParkingLocation.isValidPrice(pricePerHour)) {
      state = state.copyWith(
        error: 'Price must be between Rs. 0 and Rs. 100 per hour.',
      );
      return;
    }
    final now = DateTime.now();
    final center = state.region.boundaryPoints.length >= 3
        ? GeometryUtils.calculatePolygonCenter(state.region.boundaryPoints)
        : GeoPointValue(
            latitude: state.region.centerLat,
            longitude: state.region.centerLng,
          );
    final location = ParkingLocation(
      id: 'loc_${now.millisecondsSinceEpoch}',
      regionId: state.region.regionId,
      adminId: state.admin!.id,
      name: name.trim(),
      description: description.trim().isEmpty
          ? 'New parking area inside ${state.region.name}.'
          : description.trim(),
      address: address.trim(),
      boundaryPoints: const [],
      gatePoints: const [],
      latitude: center.latitude,
      longitude: center.longitude,
      totalSpaces: totalSpaces,
      availableSpaces: availableSpaces,
      pricePerHour: pricePerHour,
      vehicleTypes: vehicleTypes,
      thumbnailRefs: const [],
      imagePreviewRefs: const [],
      isOpen: true,
      openingTime: openingTime,
      closingTime: closingTime,
      createdAt: now,
      updatedAt: now,
    );
    await _parkingRepository.upsert(location);
    await load();
    state = state.copyWith(selectedLocation: location);
    await _loadSelectedImages();
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
    final spaceError = _validateSpaces(
      totalSpaces: totalSpaces,
      availableSpaces: availableSpaces,
    );
    if (spaceError != null) {
      state = state.copyWith(error: spaceError);
      return;
    }
    if (!ParkingLocation.isValidPrice(pricePerHour)) {
      state = state.copyWith(
        error: 'Price must be between Rs. 0 and Rs. 100 per hour.',
      );
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
      await _loadSelectedImages();
    }
  }

  Future<void> updateSelectedDetails({
    required String name,
    required String description,
    required String address,
  }) async {
    final location = state.selectedLocation;
    if (location == null) {
      return;
    }
    final cleanName = name.trim();
    final cleanAddress = address.trim();
    if (cleanName.isEmpty) {
      state = state.copyWith(error: 'Parking area name is required.');
      return;
    }
    if (cleanAddress.isEmpty) {
      state = state.copyWith(error: 'Parking area address is required.');
      return;
    }
    final updated = location.copyWith(
      name: cleanName,
      description: description.trim(),
      address: cleanAddress,
      updatedAt: DateTime.now(),
    );
    await _parkingRepository.upsert(updated);
    await load();
    final refreshed = await _parkingRepository.findById(location.id);
    if (refreshed != null) {
      state = state.copyWith(selectedLocation: refreshed);
      await _loadSelectedImages();
    }
  }

  String? _validateSpaces({
    required int totalSpaces,
    required int availableSpaces,
  }) {
    if (totalSpaces < 0) {
      return 'Total spaces cannot be negative.';
    }
    if (availableSpaces < 0) {
      return 'Available spaces cannot be negative.';
    }
    if (availableSpaces > totalSpaces) {
      return 'Available spaces must be between 0 and total spaces.';
    }
    return null;
  }

  String? _validateAreaForSave(ParkingLocation location) {
    if (!state.hasControlledRegion || state.region.boundaryPoints.length < 3) {
      return 'Set up your controlled region before saving parking areas.';
    }
    if (location.regionId != state.region.regionId) {
      return 'Parking area must belong to your controlled region.';
    }
    if (!ParkingLocation.isValidPrice(location.pricePerHour)) {
      return 'Price must be between Rs. 0 and Rs. 100 per hour.';
    }
    if (state.draftBoundaryPoints.length < 3) {
      return 'Parking area polygon must have at least 3 points.';
    }
    if (!GeometryUtils.polygonInsidePolygon(
      state.draftBoundaryPoints,
      state.region.boundaryPoints,
    )) {
      return 'Parking area must be inside your controlled region.';
    }
    final center = GeometryUtils.calculatePolygonCenter(
      state.draftBoundaryPoints,
    );
    if (!GeometryUtils.pointInPolygon(center, state.region.boundaryPoints)) {
      return 'Parking area center must be inside your controlled region.';
    }
    for (final gate in state.draftGatePoints) {
      if (!GeometryUtils.gateInsideRegion(gate, state.region.boundaryPoints)) {
        return 'Gate must be inside your controlled region.';
      }
    }
    final conflict = state.draftAreaConflict;
    if (conflict != null) {
      return conflict.message;
    }
    return _validateSpaces(
      totalSpaces: location.totalSpaces,
      availableSpaces: location.availableSpaces,
    );
  }

  bool _isInsideControlledRegion(GeoPointValue point) {
    return state.hasControlledRegion &&
        GeometryUtils.pointInPolygon(point, state.region.boundaryPoints);
  }

  Future<void> markCompleted(Booking booking) async {
    if (booking.qrId == null) {
      await _bookingRepository.updateStatus(
        bookingId: booking.id,
        status: BookingStatus.completed,
      );
    } else {
      await _bookingRepository.consumeQrTicket(booking.qrId!);
    }
    await load();
  }

  Future<void> updateIssueStatus(IssueReport issue, IssueStatus status) async {
    await _issueRepository.updateIssueStatus(
      issueId: issue.issueId,
      status: status,
    );
    final admin = state.admin;
    if (admin == null) {
      return;
    }
    final issues = await _issueRepository.getForAdmin(admin.id);
    state = state.copyWith(issues: issues);
  }

  Future<void> uploadAreaImage(Uint8List bytes) async {
    final location = state.selectedLocation;
    if (location == null) {
      state = state.copyWith(error: 'Select a parking area before uploading.');
      return;
    }

    state = state.copyWith(
      imageUploadProgress: 0.2,
      imageStatusMessage: 'Compressing image and generating thumbnail...',
    );

    try {
      final image = await _imageRepository.uploadOptimizedAreaImage(
        areaId: location.id,
        uploadedByAdminId: state.admin!.id,
        originalBytes: bytes,
      );
      state = state.copyWith(
        imageUploadProgress: 0.72,
        imageStatusMessage:
            'Thumbnail ${image.thumbnailSizeBytes}B, preview ${image.previewSizeBytes}B ready.',
      );
      final updated = location.copyWith(
        thumbnailRefs: [image.imageId, ...location.thumbnailRefs],
        imagePreviewRefs: [image.imageId, ...location.imagePreviewRefs],
        updatedAt: DateTime.now(),
      );
      await _parkingRepository.upsert(updated);
      state = state.copyWith(
        selectedLocation: updated,
        imageUploadProgress: 1,
        imageStatusMessage: 'Optimized image saved to Firestore image mode.',
      );
      await load();
      state = state.copyWith(selectedLocation: updated);
      await _loadSelectedImages();
    } on ImageOptimizationException catch (error) {
      state = state.copyWith(
        imageUploadProgress: 0,
        imageStatusMessage: error.message,
      );
    }
  }

  Future<void> removeImage(ParkingAreaImage image) async {
    final location = state.selectedLocation;
    if (location == null) {
      return;
    }
    await _imageRepository.removeImage(image.imageId);
    final updated = location.copyWith(
      thumbnailRefs: location.thumbnailRefs
          .where((id) => id != image.imageId)
          .toList(),
      imagePreviewRefs: location.imagePreviewRefs
          .where((id) => id != image.imageId)
          .toList(),
      updatedAt: DateTime.now(),
    );
    await _parkingRepository.upsert(updated);
    state = state.copyWith(
      selectedLocation: updated,
      imageStatusMessage: 'Image removed from parking area.',
    );
    await load();
    state = state.copyWith(selectedLocation: updated);
    await _loadSelectedImages();
  }

  Future<void> replaceImage(ParkingAreaImage image, Uint8List bytes) async {
    state = state.copyWith(
      imageUploadProgress: 0.25,
      imageStatusMessage: 'Replacing image with optimized version...',
    );
    final replacement = await _imageRepository.replaceImage(
      imageId: image.imageId,
      originalBytes: bytes,
    );
    state = state.copyWith(
      imageUploadProgress: 1,
      imageStatusMessage:
          'Replacement saved: preview ${replacement.previewSizeBytes}B.',
    );
    await _loadSelectedImages();
  }

  Future<void> _loadSelectedImages() async {
    final location = state.selectedLocation;
    if (location == null) {
      state = state.copyWith(selectedImages: const []);
      return;
    }
    try {
      final images = await _imageRepository.getPreviewsForArea(
        areaId: location.id,
        limit: 6,
      );
      state = state.copyWith(selectedImages: images);
    } on Object catch (error) {
      state = state.copyWith(
        selectedImages: const [],
        error: FirebaseErrorMessages.friendlyMessage(error),
      );
    }
  }

  void _startRealtimeListeners(String adminId) {
    _startReferenceRegionUpdates(adminId);
    _parkingSubscription ??= _parkingRepository
        .watchByAdmin(adminId, limit: 50)
        .listen(
          (locations) => state = state.copyWith(
            locations: locations
                .where((location) => location.regionId == state.region.regionId)
                .toList(),
          ),
          onError: (Object error) {
            state = state.copyWith(
              isLoading: false,
              error: FirebaseErrorMessages.friendlyMessage(error),
            );
          },
        );
    _referenceParkingSubscription ??= _parkingRepository
        .watchAllAreas(limit: 500)
        .listen(
          (locations) => state = state.copyWith(
            referenceLocations: locations,
            locations: locations
                .where(
                  (location) =>
                      location.adminId == adminId &&
                      location.regionId == state.region.regionId,
                )
                .toList(),
          ),
          onError: (Object error) {
            state = state.copyWith(
              isLoading: false,
              error: FirebaseErrorMessages.friendlyMessage(error),
            );
          },
        );
    _bookingSubscription ??= _bookingRepository
        .watchForAdmin(adminId, limit: 50)
        .listen(
          (bookings) => state = state.copyWith(bookings: bookings),
          onError: (Object error) {
            state = state.copyWith(
              isLoading: false,
              error: FirebaseErrorMessages.friendlyMessage(error),
            );
          },
        );
    _issueSubscription ??= _issueRepository
        .watchForAdmin(adminId)
        .listen(
          (issues) => state = state.copyWith(issues: issues),
          onError: (Object error) {
            state = state.copyWith(
              isLoading: false,
              error: FirebaseErrorMessages.friendlyMessage(error),
            );
          },
        );
  }

  void _startReferenceRegionUpdates(String adminId) {
    _referenceRegionSubscription ??= _regionRepository.watchAllRegions().listen(
      (regions) => state = state.copyWith(
        referenceRegions: regions
            .where((region) => region.createdByAdminId != adminId)
            .toList(),
      ),
      onError: (Object error) {
        state = state.copyWith(
          isLoading: false,
          error: FirebaseErrorMessages.friendlyMessage(error),
        );
      },
    );
  }

  Future<void> _resetRealtimeListeners() async {
    await _parkingSubscription?.cancel();
    await _referenceParkingSubscription?.cancel();
    await _referenceRegionSubscription?.cancel();
    await _bookingSubscription?.cancel();
    await _issueSubscription?.cancel();
    _parkingSubscription = null;
    _referenceParkingSubscription = null;
    _referenceRegionSubscription = null;
    _bookingSubscription = null;
    _issueSubscription = null;
  }

  @override
  void dispose() {
    _parkingSubscription?.cancel();
    _referenceParkingSubscription?.cancel();
    _referenceRegionSubscription?.cancel();
    _bookingSubscription?.cancel();
    _issueSubscription?.cancel();
    super.dispose();
  }
}
