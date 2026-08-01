import 'package:fittrack/screens/profile/edit_profile_screen.dart';
import 'package:fittrack/services/notification_service.dart';
import 'package:fittrack/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> createCleanAccount() async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      firebaseAvailable: false,
      notificationService: NotificationService(),
    );
    await state.initialize();
    final registered = await state.register(
      'Người kiểm thử',
      'profile-validation@fittrack.vn',
      'FitTrack123!',
    );
    expect(registered, isTrue);
    state.profile = state.profile.copyWith(heightCm: 170, currentWeightKg: 65);
    return state;
  }

  test('rejects an empty profile name without mutation', () async {
    final state = await createCleanAccount();
    final original = state.profile;

    await expectLater(
      state.updateProfile(original.copyWith(name: '   ')),
      throwsArgumentError,
    );

    expect(state.profile.name, original.name);
  });

  test('rejects profile height outside 100 to 250 centimeters', () async {
    final state = await createCleanAccount();

    await expectLater(
      state.updateProfile(state.profile.copyWith(heightCm: 99.9)),
      throwsArgumentError,
    );
    await expectLater(
      state.updateProfile(state.profile.copyWith(heightCm: 250.1)),
      throwsArgumentError,
    );
  });

  test('rejects invalid profile weight', () async {
    final state = await createCleanAccount();

    for (final weight in [0.0, -1.0, 500.1]) {
      await expectLater(
        state.updateProfile(state.profile.copyWith(currentWeightKg: weight)),
        throwsArgumentError,
      );
    }
  });

  test('rejects weekly workout goal outside 1 to 7 sessions', () async {
    final state = await createCleanAccount();

    await expectLater(
      state.updateProfile(state.profile.copyWith(weeklyWorkoutGoal: 0)),
      throwsArgumentError,
    );
    await expectLater(
      state.updateProfile(state.profile.copyWith(weeklyWorkoutGoal: 8)),
      throwsArgumentError,
    );
  });

  test('trims and persists a valid profile update', () async {
    final state = await createCleanAccount();

    await state.updateProfile(
      state.profile.copyWith(
        name: '  Lê Tiến Hải  ',
        heightCm: 172,
        currentWeightKg: 68,
        weeklyWorkoutGoal: 4,
      ),
    );
    await state.signOut();
    final signedIn = await state.signIn(
      'profile-validation@fittrack.vn',
      'FitTrack123!',
    );

    expect(signedIn, isTrue);
    expect(state.profile.name, 'Lê Tiến Hải');
    expect(state.profile.heightCm, 172);
    expect(state.profile.currentWeightKg, 68);
    expect(state.profile.weeklyWorkoutGoal, 4);
  });

  testWidgets('edit profile form shows metric range errors', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = await createCleanAccount();
    await tester.pumpWidget(MaterialApp(home: EditProfileScreen(state: state)));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(1), '99');
    await tester.enterText(fields.at(2), '501');
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pump();

    expect(find.text('Chiều cao phải tương đương 100–250 cm'), findsOneWidget);
    expect(
      find.text('Cân nặng phải trên 0 và không quá 500 kg'),
      findsOneWidget,
    );
    expect(state.profile.heightCm, 170);
    expect(state.profile.currentWeightKg, 65);
    expect(tester.takeException(), isNull);
  });
}
