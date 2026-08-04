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
      'profile-dialogs@fittrack.vn',
      'FitTrack123!',
    );
    expect(registered, isTrue);
    return state;
  }

  Future<void> pumpProfile(WidgetTester tester, AppState state) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: ProfileScreen(state: state)));
    await tester.pumpAndSettle();
  }

  Future<void> openAdvancedSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Thông báo và cài đặt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cài đặt và tiện ích'));
    await tester.pumpAndSettle();
  }

  testWidgets('display name dialog validates and saves through AppState', (
    tester,
  ) async {
    final state = await createState();
    await pumpProfile(tester, state);

    await tester.tap(find.text('Lê Tiến Hải'));
    await tester.pumpAndSettle();

    expect(find.text('Tên hiển thị'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('rename_profile_name')), '   ');
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    expect(find.text('Tên hiển thị không được để trống'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('rename_profile_name')),
      'Hải FitTrack',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(state.profile.name, 'Hải FitTrack');
    expect(find.text('Hải FitTrack'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logout dialog matches Figma and cancel keeps the session', (
    tester,
  ) async {
    final state = await createState();
    await pumpProfile(tester, state);

    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();

    expect(find.text('Đăng xuất?'), findsOneWidget);
    expect(
      find.text('Buổi tập đang dở sẽ được xóa khỏi thiết bị khi đăng xuất.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    expect(state.isAuthenticated, isTrue);
    expect(find.text('Đăng xuất?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('privacy dialog presents the four Figma safety points', (
    tester,
  ) async {
    final state = await createState();
    await pumpProfile(tester, state);
    await openAdvancedSettings(tester);

    final privacyAction = find.text('Quyền riêng tư, an toàn và nguồn');
    await tester.scrollUntilVisible(
      privacyAction,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(privacyAction);
    await tester.pumpAndSettle();

    expect(find.text('Quyền riêng tư và an toàn'), findsOneWidget);
    expect(find.text('Xử lý trên thiết bị, không lưu video.'), findsOneWidget);
    expect(find.text('Dữ liệu sức khỏe được bảo vệ.'), findsOneWidget);
    expect(find.text('Camera Coach có Guided Confirmation.'), findsOneWidget);
    expect(find.text('BMI chỉ mang tính tham khảo.'), findsOneWidget);
    expect(find.text('Đã hiểu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delete-account dialog is destructive and can be cancelled', (
    tester,
  ) async {
    final state = await createState();
    await pumpProfile(tester, state);
    await openAdvancedSettings(tester);

    final deleteAction = find.text('Yêu cầu xóa tài khoản và dữ liệu');
    await tester.scrollUntilVisible(
      deleteAction,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(deleteAction);
    await tester.pumpAndSettle();

    expect(find.text('Gửi yêu cầu xóa tài khoản?'), findsOneWidget);
    expect(
      find.text(
        'FitTrack sẽ ghi nhận yêu cầu, đăng xuất và xóa bản dữ liệu cục bộ của tài khoản này.',
      ),
      findsOneWidget,
    );
    expect(find.text('Gửi yêu cầu'), findsOneWidget);

    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(state.isAuthenticated, isTrue);
    expect(find.text('Gửi yêu cầu xóa tài khoản?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
