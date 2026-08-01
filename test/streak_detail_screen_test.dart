import 'package:fittrack/screens/history/streak_detail_screen.dart';
import 'package:fittrack/services/notification_service.dart';
import 'package:fittrack/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> createState() async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      firebaseAvailable: false,
      notificationService: NotificationService(),
    );
    await state.initialize();
    return state;
  }

  testWidgets('workout streak detail follows the Figma structure', (
    tester,
  ) async {
    final state = await createState();
    final today = DateTime.now();
    state.workoutDays.addAll([
      dateKey(today.subtract(const Duration(days: 1))),
      dateKey(today),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: StreakDetailScreen(state: state, kind: StreakKind.workout),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FitTrack'), findsOneWidget);
    expect(find.text('2 Ngày'), findsAtLeastNWidgets(2));
    expect(find.text('Chuỗi tập luyện hiện tại'), findsOneWidget);
    expect(find.text('Kỷ lục dài nhất'), findsOneWidget);
    expect(find.text('Tổng ngày hoạt động'), findsOneWidget);
    expect(find.text('Lịch sử hoạt động (28 ngày)'), findsOneWidget);
    expect(find.text('Cách duy trì Streak'), findsOneWidget);
  });

  testWidgets('weight streak stays separate from workout streak', (
    tester,
  ) async {
    final state = await createState();
    final today = DateTime.now();
    state.activeDays.add(dateKey(today));
    state.workoutDays.addAll([
      dateKey(today.subtract(const Duration(days: 1))),
      dateKey(today),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: StreakDetailScreen(state: state, kind: StreakKind.weight),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 Ngày'), findsAtLeastNWidgets(2));
    expect(find.text('Chuỗi nhập cân hiện tại'), findsOneWidget);
    expect(
      find.text('Nhiều lần cập nhật cùng ngày vẫn chỉ được tính một ngày.'),
      findsOneWidget,
    );
  });
}

String dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
