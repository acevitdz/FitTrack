import 'package:fittrack/screens/profile/profile_screen.dart';
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
    final registered = await state.register(
      'Lê Tiến Hải',
      'profile-screen@fittrack.vn',
      'FitTrack123!',
    );
    expect(registered, isTrue);
    return state;
  }

  Future<void> pumpProfile(WidgetTester tester, AppState state) async {
    tester.view.physicalSize = const Size(390, 855);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: ProfileScreen(state: state)));
    await tester.pumpAndSettle();
  }

  testWidgets('profile screen follows the UI-11 primary structure', (
    tester,
  ) async {
    final state = await createState();
    await pumpProfile(tester, state);

    expect(find.text('FitTrack'), findsOneWidget);
    expect(find.text('Lê Tiến Hải'), findsOneWidget);
    expect(find.text('profile-screen@fittrack.vn'), findsOneWidget);
    expect(find.text('Chỉnh sửa hồ sơ'), findsOneWidget);
    expect(find.text('Chỉ số cơ thể'), findsOneWidget);
    expect(find.text('Báo cáo tổng kết'), findsOneWidget);
    expect(find.text('Nhắc nhở luyện tập'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('summary report tile opens the progress report', (tester) async {
    final state = await createState();
    await pumpProfile(tester, state);

    await tester.tap(find.text('Báo cáo tổng kết'));
    await tester.pumpAndSettle();

    expect(find.text('Báo cáo hiệu suất'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('advanced settings remain reachable from the notification menu', (
    tester,
  ) async {
    final state = await createState();
    await pumpProfile(tester, state);

    await tester.tap(find.byTooltip('Thông báo và cài đặt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cài đặt và tiện ích'));
    await tester.pumpAndSettle();

    expect(find.text('Cài đặt và tiện ích'), findsOneWidget);
    expect(find.text('Luyện tập'), findsOneWidget);
    expect(find.text('Thành tích'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
