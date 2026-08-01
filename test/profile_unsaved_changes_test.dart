import 'package:fittrack/screens/profile/edit_profile_screen.dart';
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
      'Người kiểm thử',
      'profile-unsaved@fittrack.vn',
      'FitTrack123!',
    );
    expect(registered, isTrue);
    state.profile = state.profile.copyWith(heightCm: 170, currentWeightKg: 65);
    return state;
  }

  Future<void> pumpEditor(WidgetTester tester, AppState state) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(state: state),
                  ),
                ),
                child: const Text('Mở chỉnh sửa'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở chỉnh sửa'));
    await tester.pumpAndSettle();
    expect(find.text('Chỉnh sửa hồ sơ'), findsOneWidget);
  }

  testWidgets('unchanged profile closes without confirmation', (tester) async {
    final state = await createState();
    await pumpEditor(tester, state);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Bỏ thay đổi?'), findsNothing);
    expect(find.text('Mở chỉnh sửa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edited profile asks before discarding changes', (tester) async {
    final state = await createState();
    await pumpEditor(tester, state);

    final nameField = find.byType(TextFormField).first;
    await tester.enterText(nameField, 'Tên chưa lưu');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Bỏ thay đổi?'), findsOneWidget);
    expect(find.text('Các thay đổi chưa lưu sẽ bị mất.'), findsOneWidget);

    await tester.tap(find.text('Tiếp tục chỉnh sửa'));
    await tester.pumpAndSettle();
    expect(find.text('Chỉnh sửa hồ sơ'), findsOneWidget);
    expect(find.text('Bỏ thay đổi?'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ thay đổi'));
    await tester.pumpAndSettle();

    expect(find.text('Mở chỉnh sửa'), findsOneWidget);
    expect(state.profile.name, isNot('Tên chưa lưu'));
    expect(tester.takeException(), isNull);
  });
}
