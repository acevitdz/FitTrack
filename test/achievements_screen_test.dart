import 'package:fittrack/screens/profile/achievements_screen.dart';
import 'package:fittrack/services/notification_service.dart';
import 'package:fittrack/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('achievements match the Figma grid and show milestone details', (
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

    expect(find.text('Thành tích'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Buổi tập đầu tiên'), findsOneWidget);
    expect(find.text('Chuỗi 7 ngày'), findsOneWidget);
    expect(find.text('Streak 3 ngày'), findsOneWidget);
    expect(find.text('50 buổi tập'), findsOneWidget);
    expect(find.text('Chưa mở khóa'), findsNWidgets(4));

    await tester.tap(find.text('Buổi tập đầu tiên'));
    await tester.pumpAndSettle();

    expect(find.text('Còn 1 buổi để mở khóa'), findsOneWidget);
  });

  testWidgets('achievement overflow menu filters locked milestones', (
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

    await tester.tap(find.byTooltip('Lọc thành tích'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã mở khóa'));
    await tester.pumpAndSettle();

    expect(find.text('Không có thành tích phù hợp'), findsOneWidget);
  });
}
