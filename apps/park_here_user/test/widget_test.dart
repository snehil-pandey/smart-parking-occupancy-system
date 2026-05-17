// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:park_here_user/main.dart';
import 'package:park_here_user/src/user_app_controller.dart';
import 'package:park_here_shared/park_here_shared.dart';

void main() {
  testWidgets('Park Here user app renders', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(LocalAuthService()),
          parkingRepositoryProvider.overrideWithValue(
            InMemoryParkingRepository(),
          ),
          bookingRepositoryProvider.overrideWithValue(
            InMemoryBookingRepository(),
          ),
          imageRepositoryProvider.overrideWithValue(InMemoryImageRepository()),
          reviewRepositoryProvider.overrideWithValue(
            InMemoryReviewRepository(),
          ),
          issueRepositoryProvider.overrideWithValue(InMemoryIssueRepository()),
          firebaseReadinessProvider.overrideWithValue(
            const FirebaseReadiness(
              isConfigured: true,
              message: 'Test Firebase readiness.',
            ),
          ),
        ],
        child: const ParkHereUserApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nearby parking'), findsOneWidget);
  });
}
