import 'package:fittrack/screens/onboarding/onboarding_screen.dart';
import 'package:fittrack/services/notification_service.dart';
import 'package:fittrack/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> createState({bool includeBirthDate = true}) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      firebaseAvailable: false,
      notificationService: NotificationService(),
    );
    await state.initialize();
    state.profile = state.profile.copyWith(
      name: 'Lê Tiến Hải',
      heightCm: 170,
      currentWeightKg: 68,
      targetWeightKg: 64,
      dateOfBirth: includeBirthDate ? DateTime(1995, 8, 15) : null,
      onboardingCompleted: false,
    );
    return state;
  }

  Future<void> pumpOnboarding(WidgetTester tester, AppState state) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: OnboardingScreen(state: state),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> continueToNextStep(WidgetTester tester) async {
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
  }

  testWidgets('onboarding displays the four Figma steps UI-05 to UI-08', (
    tester,
  ) async {
    final state = await createState();
    await pumpOnboarding(tester, state);

    expect(find.byKey(const ValueKey('ui-05-personal')), findsOneWidget);
    expect(find.text('Thông tin cá nhân'), findsOneWidget);
    expect(find.text('BƯỚC 1 CỦA 4'), findsOneWidget);
    expect(find.byKey(const Key('onboarding_birth_date')), findsOneWidget);

    await continueToNextStep(tester);

    expect(find.byKey(const ValueKey('ui-06-metrics')), findsOneWidget);
    expect(find.text('Chỉ số cơ thể'), findsOneWidget);
    expect(find.text('BƯỚC 2 CỦA 4'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-bmi-preview')),
      findsOneWidget,
    );
    expect(find.text('23.5'), findsOneWidget);

    await continueToNextStep(tester);

    expect(find.byKey(const ValueKey('ui-07-goals')), findsOneWidget);
    expect(find.text('Mục tiêu luyện tập'), findsOneWidget);
    expect(find.text('BƯỚC 3 CỦA 4'), findsOneWidget);
    expect(find.text('Giảm mỡ'), findsOneWidget);
    expect(find.text('Tăng cơ'), findsOneWidget);

    await continueToNextStep(tester);

    expect(find.byKey(const ValueKey('ui-08-complete')), findsOneWidget);
    expect(find.text('Thiết lập hoàn tất!'), findsOneWidget);
    expect(find.text('BƯỚC 4 CỦA 4'), findsOneWidget);
    expect(find.text('Bắt đầu hành trình'), findsOneWidget);
    expect(find.text('Chương trình dành cho bạn'), findsOneWidget);
  });

  testWidgets('onboarding requires a birth date before leaving UI-05', (
    tester,
  ) async {
    final state = await createState(includeBirthDate: false);
    await pumpOnboarding(tester, state);

    await continueToNextStep(tester);

    expect(find.text('Hãy chọn ngày sinh'), findsOneWidget);
    expect(find.byKey(const ValueKey('ui-05-personal')), findsOneWidget);
    expect(find.text('BƯỚC 1 CỦA 4'), findsOneWidget);
  });

  testWidgets('finishing UI-08 persists profile, preferences and metrics', (
    tester,
  ) async {
    final state = await createState();
    final initialWeightEntryCount = state.weightEntries.length;
    await pumpOnboarding(tester, state);

    await continueToNextStep(tester);
    await continueToNextStep(tester);
    await continueToNextStep(tester);

    await tester.tap(find.text('Bắt đầu hành trình'));
    await tester.pumpAndSettle();

    expect(state.profile.onboardingCompleted, isTrue);
    expect(state.profile.name, 'Lê Tiến Hải');
    expect(state.profile.dateOfBirth, DateTime(1995, 8, 15));
    expect(state.profile.heightCm, closeTo(170, 0.01));
    expect(state.profile.currentWeightKg, closeTo(68, 0.01));
    expect(state.profile.targetWeightKg, closeTo(64, 0.01));
    expect(state.profile.weeklyWorkoutGoal, 3);
    expect(state.trainingPreferences.sessionsPerWeek, 3);
    expect(state.weightEntries, hasLength(initialWeightEntryCount + 1));
  });
}
