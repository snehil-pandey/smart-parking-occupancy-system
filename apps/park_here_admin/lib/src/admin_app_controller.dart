import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:park_here_shared/park_here_shared.dart';

final adminAuthProvider = Provider<AuthService>((ref) => LocalAuthService());
final adminParkingRepositoryProvider = Provider<ParkingRepository>(
  (ref) => InMemoryParkingRepository(),
);
final adminBookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => InMemoryBookingRepository(),
);
final adminImageRepositoryProvider = Provider<ImageRepository>(
  (ref) => InMemoryImageRepository(),
);
final adminRegionRepositoryProvider = Provider<RegionRepository>(
  (ref) => InMemoryRegionRepository(),
);
final adminIssueRepositoryProvider = Provider<IssueRepository>(
  (ref) => InMemoryIssueRepository(),
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
        imageRepository: ref.watch(adminImageRepositoryProvider),
        regionRepository: ref.watch(adminRegionRepositoryProvider),
        issueRepository: ref.watch(adminIssueRepositoryProvider),
      )..load();
    });

enum AdminSection { region, parkingAreas, issues }

class AdminAppState {
  const AdminAppState({
    required this.admin,
    required this.section,
    required this.region,
    required this.locations,
    required this.bookings,
    required this.issues,
    required this.selectedImages,
    required this.selectedLocation,
    required this.isLoading,
    required this.imageUploadProgress,
    required this.imageStatusMessage,
    this.error,
  });

  factory AdminAppState.initial(AdminProfile admin) {
    return AdminAppState(
      admin: admin,
      section: AdminSection.region,
      region: DemoSeed.sitTumkurRegion(),
      locations: const [],
      bookings: const [],
      issues: const [],
      selectedImages: const [],
      selectedLocation: null,
      isLoading: true,
      imageUploadProgress: 0,
      imageStatusMessage: 'Images are optimized before Firestore upload.',
    );
  }

  final AdminProfile admin;
  final AdminSection section;
  final ParkingRegion region;
  final List<ParkingLocation> locations;
  final List<Booking> bookings;
  final List<IssueReport> issues;
  final List<ParkingAreaImage> selectedImages;
  final ParkingLocation? selectedLocation;
  final bool isLoading;
  final double imageUploadProgress;
  final String imageStatusMessage;
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
    AdminSection? section,
    ParkingRegion? region,
    List<ParkingLocation>? locations,
    List<Booking>? bookings,
    List<IssueReport>? issues,
    List<ParkingAreaImage>? selectedImages,
    ParkingLocation? selectedLocation,
    bool? isLoading,
    double? imageUploadProgress,
    String? imageStatusMessage,
    String? error,
  }) {
    return AdminAppState(
      admin: admin ?? this.admin,
      section: section ?? this.section,
      region: region ?? this.region,
      locations: locations ?? this.locations,
      bookings: bookings ?? this.bookings,
      issues: issues ?? this.issues,
      selectedImages: selectedImages ?? this.selectedImages,
      selectedLocation: selectedLocation ?? this.selectedLocation,
      isLoading: isLoading ?? this.isLoading,
      imageUploadProgress: imageUploadProgress ?? this.imageUploadProgress,
      imageStatusMessage: imageStatusMessage ?? this.imageStatusMessage,
      error: error,
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
  }) : _auth = auth,
       _parkingRepository = parkingRepository,
       _bookingRepository = bookingRepository,
       _imageRepository = imageRepository,
       _regionRepository = regionRepository,
       _issueRepository = issueRepository,
       super(AdminAppState.initial(auth.currentAdmin));

  final AuthService _auth;
  final ParkingRepository _parkingRepository;
  final BookingRepository _bookingRepository;
  final ImageRepository _imageRepository;
  final RegionRepository _regionRepository;
  final IssueRepository _issueRepository;

  Future<void> load() async {
    final region = await _regionRepository.getMainRegion();
    final locations = await _parkingRepository.getByRegion(region.regionId);
    final bookings = await _bookingRepository.getForAdmin(
      _auth.currentAdmin.id,
    );
    final issues = await _issueRepository.getForAdmin(_auth.currentAdmin.id);
    state = state.copyWith(
      region: region,
      locations: locations,
      bookings: bookings,
      issues: issues,
      selectedLocation: locations.firstOrNull,
      isLoading: false,
    );
    await _loadSelectedImages();
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
    state = state.copyWith(admin: admin);
    await load();
  }

  Future<void> selectLocation(ParkingLocation location) async {
    state = state.copyWith(selectedLocation: location);
    await _loadSelectedImages();
  }

  Future<void> saveRegionBoundary(List<GeoPointValue> points) async {
    final updated = state.region.copyWith(
      boundaryPoints: points,
      updatedAt: DateTime.now(),
    );
    await _regionRepository.upsertRegion(updated);
    state = state.copyWith(region: updated);
  }

  Future<void> nudgeRegionBoundary() async {
    final updated = state.region.boundaryPoints
        .map(
          (point) => GeoPointValue(
            latitude: point.latitude + 0.0001,
            longitude: point.longitude,
          ),
        )
        .toList();
    await saveRegionBoundary(updated);
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
  }) async {
    final now = DateTime.now();
    final location = ParkingLocation(
      id: 'loc_${now.millisecondsSinceEpoch}',
      regionId: state.region.regionId,
      adminId: state.admin.id,
      name: name,
      description: 'New parking area inside ${state.region.name}.',
      address: address,
      boundaryPoints: const [
        GeoPointValue(latitude: 13.3500, longitude: 77.1020),
        GeoPointValue(latitude: 13.3502, longitude: 77.1026),
        GeoPointValue(latitude: 13.3496, longitude: 77.1028),
        GeoPointValue(latitude: 13.3494, longitude: 77.1021),
      ],
      latitude: latitude,
      longitude: longitude,
      totalSpaces: totalSpaces,
      availableSpaces: availableSpaces.clamp(0, totalSpaces),
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

  Future<void> markCompleted(Booking booking) async {
    await _bookingRepository.updateStatus(
      bookingId: booking.id,
      status: BookingStatus.completed,
    );
    await load();
  }

  Future<void> updateIssueStatus(IssueReport issue, IssueStatus status) async {
    await _issueRepository.updateIssueStatus(
      issueId: issue.issueId,
      status: status,
    );
    final issues = await _issueRepository.getForAdmin(state.admin.id);
    state = state.copyWith(issues: issues);
  }

  Future<void> uploadDemoImage() async {
    await uploadAreaImage(Uint8List.fromList(DemoSeed.demoUploadBytes()));
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
        uploadedByAdminId: state.admin.id,
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

  Future<void> replaceImage(ParkingAreaImage image) async {
    state = state.copyWith(
      imageUploadProgress: 0.25,
      imageStatusMessage: 'Replacing image with optimized version...',
    );
    final replacement = await _imageRepository.replaceImage(
      imageId: image.imageId,
      originalBytes: Uint8List.fromList(DemoSeed.demoUploadBytes()),
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
    final images = await _imageRepository.getPreviewsForArea(
      areaId: location.id,
      limit: 6,
    );
    state = state.copyWith(selectedImages: images);
  }
}
