import 'package:fittrack/screens/profile/achievements_screen.dart';
import 'package:fittrack/services/notification_service.dart';
import 'package:fittrack/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('achievements show progress and milestone details', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      firebaseAvailable: false,
      notificationService: NotificationService(),
    );
    await state.initialize();

    await tester.pumpWidget(
      MaterialApp(home: AchievementsScreen(state: state)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mốc buổi tập'), findsOneWidget);
    expect(find.text('Khởi đầu mạnh mẽ'), findsOneWidget);
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('Đã mở'), findsOneWidget);
    expect(find.text('Chưa mở'), findsOneWidget);

    await tester.tap(find.text('Khởi đầu mạnh mẽ'));
    await tester.pumpAndSettle();

    expect(find.text('Còn 1 buổi để mở khóa'), findsOneWidget);
  });
}
