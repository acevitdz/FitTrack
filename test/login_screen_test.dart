import 'package:fittrack/screens/auth/login_screen.dart';
import 'package:fittrack/services/local_store.dart';
import 'package:fittrack/services/notification_service.dart';
import 'package:fittrack/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestStore extends LocalStore {
  @override
  Future<bool> loadAuthenticated() async => false;

  @override
  Future<Map<String, dynamic>?> loadState() async => null;

  @override
  Future<void> saveAuthenticated(bool value) async {}

  @override
  Future<String?> loadAuthenticatedUid() async => null;

  @override
  Future<void> saveAuthenticatedUid(String? uid) async {}

  @override
  Future<void> saveState(Map<String, dynamic> data) async {}
}

class TestNotifications extends NotificationService {
  @override
  Future<void> initialize() async {}
}

void main() {
  testWidgets('login form shows validation and can switch to registration', (
    tester,
  ) async {
    final state = AppState(
      firebaseAvailable: false,
      notificationService: TestNotifications(),
      localStore: TestStore(),
    );
    await state.initialize();

    await tester.pumpWidget(MaterialApp(home: LoginScreen(state: state)));

    expect(find.text('FitTrack'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets);
    final registerLink = find.text('Chưa có tài khoản? Đăng ký');
    await tester.ensureVisible(registerLink);
    await tester.tap(registerLink);
    await tester.pump();
    expect(find.text('Họ và tên'), findsOneWidget);
    expect(find.text('Tạo tài khoản mới'), findsOneWidget);
  });
}
