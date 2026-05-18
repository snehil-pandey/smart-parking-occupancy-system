import 'dart:typed_data';

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

    expect(find.text('Region Management'), findsOneWidget);
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
    await controller.markCurrentPositionAsCorner();
    await controller.markCurrentPositionAsGate(name: 'Main Gate');

    expect(controller.state.draftBoundaryPoints, hasLength(1));
    expect(controller.state.draftGatePoints, hasLength(1));
    expect(controller.state.draftGatePoints.first.name, 'Main Gate');
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
