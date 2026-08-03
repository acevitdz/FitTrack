import 'package:fittrack/screens/auth/forgot_password_screen.dart';
import 'package:fittrack/screens/auth/login_screen.dart';
import 'package:fittrack/screens/auth/splash_screen.dart';
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

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: ThemeData(useMaterial3: true), home: screen),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('UI-01 shows the FitTrack splash and finishes once', (
    tester,
  ) async {
    var finishedCount = 0;
    await pumpScreen(
      tester,
      SplashScreen(onFinished: () => finishedCount++),
      settle: false,
    );

    expect(find.byKey(const ValueKey('ui-01-splash')), findsOneWidget);
    expect(find.text('FitTrack'), findsOneWidget);
    expect(finishedCount, 0);

    await tester.pump(const Duration(seconds: 2));
    expect(finishedCount, 1);
  });

  testWidgets('UI-02 shows the existing login validation', (tester) async {
    final state = await createState();
    await pumpScreen(tester, LoginScreen(state: state));

    expect(find.byKey(const ValueKey('ui-02-login')), findsOneWidget);
    expect(find.text('Chào mừng trở lại'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('auth_email')), 'email-sai');
    await tester.tap(find.byKey(const Key('auth_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Email không hợp lệ'), findsOneWidget);
    expect(find.text('Mật khẩu cần ít nhất 8 ký tự'), findsOneWidget);
    expect(state.isAuthenticated, isFalse);
  });

  testWidgets('UI-03 validates registration and opens onboarding state', (
    tester,
  ) async {
    final state = await createState();
    await pumpScreen(tester, LoginScreen(state: state));

    await tester.tap(find.text('Đăng ký ngay'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ui-03-register')), findsOneWidget);
    expect(find.text('Tạo tài khoản mới'), findsOneWidget);
    expect(
      find.text('Sử dụng ít nhất 8 ký tự để bảo vệ tài khoản.'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('auth_name')), 'Lê Tiến Hải');
    await tester.enterText(
      find.byKey(const Key('auth_email')),
      'letienhai@example.com',
    );
    await tester.enterText(find.byKey(const Key('auth_password')), '123');
    await tester.enterText(
      find.byKey(const Key('auth_confirm_password')),
      '123',
    );
    await tester.tap(find.byKey(const Key('auth_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Mật khẩu cần ít nhất 8 ký tự'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('auth_password')),
      'FitTrack123!',
    );
    await tester.enterText(
      find.byKey(const Key('auth_confirm_password')),
      'FitTrack123!',
    );
    await tester.tap(find.byKey(const Key('auth_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Bạn cần đồng ý với điều khoản dịch vụ.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('auth_terms')));
    await tester.tap(find.byKey(const Key('auth_submit')));
    await tester.pumpAndSettle();

    expect(state.isAuthenticated, isTrue);
    expect(state.profile.name, 'Lê Tiến Hải');
    expect(state.profile.onboardingCompleted, isFalse);
  });

  testWidgets('UI-04 validates email and shows neutral reset success', (
    tester,
  ) async {
    final state = await createState();
    await pumpScreen(
      tester,
      ForgotPasswordScreen(state: state, initialEmail: 'email-sai'),
    );

    expect(find.byKey(const ValueKey('ui-04-forgot-password')), findsOneWidget);
    await tester.tap(find.byKey(const Key('forgot_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Email không hợp lệ'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('forgot_email')),
      'letienhai@example.com',
    );
    await tester.tap(find.byKey(const Key('forgot_submit')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('forgot-password-success')),
      findsOneWidget,
    );
    expect(find.text('Kiểm tra email của bạn'), findsOneWidget);
    expect(find.textContaining('Nếu email hợp lệ'), findsOneWidget);
  });
}
