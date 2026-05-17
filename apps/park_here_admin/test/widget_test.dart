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
    await tester.pumpWidget(const ProviderScope(child: ParkHereAdminApp()));
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
    );

    await controller.load();
    await controller.uploadDemoImage();

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
}
