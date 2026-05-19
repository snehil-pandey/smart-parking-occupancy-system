import 'dart:typed_data';
import 'dart:ui' show Size;

// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:park_here_admin/main.dart';
import 'package:park_here_admin/src/admin_app_controller.dart';
import 'package:park_here_shared/park_here_shared.dart';

void main() {
  testWidgets('admin dashboard renders', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminAuthProvider.overrideWithValue(LocalAuthService()),
          adminParkingRepositoryProvider.overrideWithValue(
            InMemoryParkingRepository(),
          ),
          adminBookingRepositoryProvider.overrideWithValue(
            InMemoryBookingRepository(),
          ),
          adminImageRepositoryProvider.overrideWithValue(
            InMemoryImageRepository(),
          ),
          adminRegionRepositoryProvider.overrideWithValue(
            InMemoryRegionRepository(),
          ),
          adminIssueRepositoryProvider.overrideWithValue(
            InMemoryIssueRepository(),
          ),
          adminFirebaseReadinessProvider.overrideWithValue(
            const FirebaseReadiness(
              isConfigured: true,
              message: 'Test Firebase readiness.',
            ),
          ),
          adminLocationServiceProvider.overrideWithValue(
            const _TestAdminLocationService(),
          ),
        ],
        child: const ParkHereAdminApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Region Management'), findsOneWidget);
    expect(find.text('Areas'), findsWidgets);
    expect(find.text('Bookings'), findsWidgets);
    expect(find.text('Issues'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
  });

  testWidgets('admin shell switches to parking areas section', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminAuthProvider.overrideWithValue(LocalAuthService()),
          adminParkingRepositoryProvider.overrideWithValue(
            InMemoryParkingRepository(),
          ),
          adminBookingRepositoryProvider.overrideWithValue(
            InMemoryBookingRepository(),
          ),
          adminImageRepositoryProvider.overrideWithValue(
            InMemoryImageRepository(),
          ),
          adminRegionRepositoryProvider.overrideWithValue(
            InMemoryRegionRepository(),
          ),
          adminIssueRepositoryProvider.overrideWithValue(
            InMemoryIssueRepository(),
          ),
          adminFirebaseReadinessProvider.overrideWithValue(
            const FirebaseReadiness(
              isConfigured: true,
              message: 'Test Firebase readiness.',
            ),
          ),
          adminLocationServiceProvider.overrideWithValue(
            const _TestAdminLocationService(),
          ),
        ],
        child: const ParkHereAdminApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Areas').last);
    await tester.pumpAndSettle();

    expect(find.text('Parking areas in SIT Tumkur'), findsOneWidget);
  });

  testWidgets('admin parking area section fits narrow mobile width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminAuthProvider.overrideWithValue(LocalAuthService()),
          adminParkingRepositoryProvider.overrideWithValue(
            InMemoryParkingRepository(),
          ),
          adminBookingRepositoryProvider.overrideWithValue(
            InMemoryBookingRepository(),
          ),
          adminImageRepositoryProvider.overrideWithValue(
            InMemoryImageRepository(),
          ),
          adminRegionRepositoryProvider.overrideWithValue(
            InMemoryRegionRepository(),
          ),
          adminIssueRepositoryProvider.overrideWithValue(
            InMemoryIssueRepository(),
          ),
          adminFirebaseReadinessProvider.overrideWithValue(
            const FirebaseReadiness(
              isConfigured: true,
              message: 'Test Firebase readiness.',
            ),
          ),
          adminLocationServiceProvider.overrideWithValue(
            const _TestAdminLocationService(),
          ),
        ],
        child: const ParkHereAdminApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Areas').last);
    await tester.pumpAndSettle();

    expect(find.text('Parking areas in SIT Tumkur'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('admin controller can run optimized image upload flow', () async {
    final auth = LocalAuthService();
    final controller = AdminAppController(
      auth: auth,
      parkingRepository: InMemoryParkingRepository(),
      bookingRepository: InMemoryBookingRepository(),
      imageRepository: InMemoryImageRepository(seed: const []),
      regionRepository: InMemoryRegionRepository(),
      issueRepository: InMemoryIssueRepository(),
      locationService: const _TestAdminLocationService(),
    );

    await controller.load();
    await controller.uploadAreaImage(
      Uint8List.fromList(DemoSeed.demoUploadBytes()),
    );

    expect(controller.state.selectedImages, isNotEmpty);
    expect(
      controller.state.selectedImages.first.thumbnailSizeBytes,
      lessThanOrEqualTo(30 * 1024),
    );
    expect(
      controller.state.selectedImages.first.previewSizeBytes,
      lessThanOrEqualTo(120 * 1024),
    );
    expect(
      controller.state.imageStatusMessage,
      contains('Optimized image saved'),
    );
  });

  test('admin controller can mark GPS corners and gates', () async {
    final controller = AdminAppController(
      auth: LocalAuthService(),
      parkingRepository: InMemoryParkingRepository(),
      bookingRepository: InMemoryBookingRepository(),
      imageRepository: InMemoryImageRepository(seed: const []),
      regionRepository: InMemoryRegionRepository(),
      issueRepository: InMemoryIssueRepository(),
      locationService: const _TestAdminLocationService(),
    );

    await controller.load();
    final initialCorners = controller.state.draftBoundaryPoints.length;
    final initialGates = controller.state.draftGatePoints.length;
    await controller.markCurrentPositionAsCorner();
    await controller.markCurrentPositionAsGate(name: 'Main Gate');

    expect(controller.state.draftBoundaryPoints, hasLength(initialCorners + 1));
    expect(controller.state.draftGatePoints, hasLength(initialGates + 1));
    expect(controller.state.draftGatePoints.last.name, 'Main Gate');
  });

  test('admin controller edits geometry from map taps and undo', () async {
    final controller = AdminAppController(
      auth: LocalAuthService(),
      parkingRepository: InMemoryParkingRepository(),
      bookingRepository: InMemoryBookingRepository(),
      imageRepository: InMemoryImageRepository(seed: const []),
      regionRepository: InMemoryRegionRepository(),
      issueRepository: InMemoryIssueRepository(),
      locationService: const _TestAdminLocationService(),
    );

    await controller.load();
    final initialCorners = controller.state.draftBoundaryPoints.length;
    controller.handleMapTap(
      const GeoPointValue(latitude: 13.3284, longitude: 77.1258),
    );

    expect(controller.state.draftBoundaryPoints, hasLength(initialCorners + 1));
    expect(
      controller.state.selectedGeometryPoint?.kind,
      AdminGeometryPointKind.corner,
    );

    controller.moveSelectedGeometryPoint(
      const GeoPointValue(latitude: 13.3285, longitude: 77.1259),
    );
    expect(controller.state.draftBoundaryPoints.last.latitude, 13.3285);

    controller.changeGeometryMode(AdminGeometryMode.gate);
    controller.clearGeometrySelection();
    controller.handleMapTap(
      const GeoPointValue(latitude: 13.3286, longitude: 77.1260),
    );
    expect(controller.state.draftGatePoints, isNotEmpty);

    controller.updateGatePoint(
      index: controller.state.draftGatePoints.length - 1,
      name: 'Student Gate',
      type: GatePointType.entry,
    );
    expect(controller.state.draftGatePoints.last.name, 'Student Gate');
    expect(controller.state.draftGatePoints.last.type, GatePointType.entry);

    controller.undoLastGeometryChange();
    expect(controller.state.draftGatePoints.last.name, isNot('Student Gate'));
  });

  test('admin controller validates area spaces before update', () async {
    final controller = AdminAppController(
      auth: LocalAuthService(),
      parkingRepository: InMemoryParkingRepository(),
      bookingRepository: InMemoryBookingRepository(),
      imageRepository: InMemoryImageRepository(seed: const []),
      regionRepository: InMemoryRegionRepository(),
      issueRepository: InMemoryIssueRepository(),
      locationService: const _TestAdminLocationService(),
    );

    await controller.load();
    await controller.updateSelectedAvailability(
      totalSpaces: 3,
      availableSpaces: 4,
      isOpen: true,
      pricePerHour: 20,
    );

    expect(controller.state.error, contains('Available spaces'));
  });
}

class _TestAdminLocationService implements AdminLocationService {
  const _TestAdminLocationService();

  @override
  Future<AdminGpsPosition> currentPosition() async {
    return const AdminGpsPosition(
      latitude: 13.3281211,
      longitude: 77.1256930,
      accuracyMeters: 8,
      isFallback: false,
      message: 'Test GPS accuracy 8 m.',
    );
  }
}
