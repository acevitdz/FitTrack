import 'package:fittrack/screens/profile/reminders_screen.dart';
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

  Future<void> pumpScreen(WidgetTester tester, AppState state) async {
    tester.view.physicalSize = const Size(390, 1046);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: RemindersScreen(state: state)));
    await tester.pumpAndSettle();
  }

  testWidgets('reminders screen follows Figma frame 37', (tester) async {
    final state = await createState();
    await pumpScreen(tester, state);

    expect(find.text('FitTrack'), findsOneWidget);
    expect(find.text('Thông báo và nhắc lịch'), findsOneWidget);
    expect(find.text('Quyền thông báo đang tắt'), findsOneWidget);
    expect(find.text('Nhắc buổi tập'), findsOneWidget);
    expect(find.text('Thời điểm nhắc'), findsOneWidget);
    expect(find.text('Đúng giờ'), findsOneWidget);
    expect(find.text('Trước 15 phút'), findsOneWidget);
    expect(find.text('Trước 30 phút'), findsOneWidget);
    expect(find.text('Trước 60 phút'), findsOneWidget);
    expect(find.text('Lịch sắp tới'), findsOneWidget);
    expect(find.text('Không có buổi sắp tới'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enabling workout reminders requests permission', (tester) async {
    final state = await createState();
    await pumpScreen(tester, state);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(state.notificationPermissionRequested, isTrue);
    expect(state.notificationPermissionGranted, isTrue);
    expect(state.notificationsEnabled, isTrue);
    expect(find.text('Quyền thông báo đang tắt'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lead-time chips update the reminder setting', (tester) async {
    final state = await createState();
    await pumpScreen(tester, state);

    await tester.tap(find.text('Trước 30 phút'));
    await tester.pumpAndSettle();

    expect(state.programReminderMinutesBefore, 30);
    final selectedChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Trước 30 phút'),
    );
    expect(selectedChip.selected, isTrue);
    expect(tester.takeException(), isNull);
  });
}
