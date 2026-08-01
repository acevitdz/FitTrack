import 'package:fittrack/models/measurement_units.dart';
import 'package:fittrack/services/notification_service.dart';
import 'package:fittrack/state/app_state.dart';
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
      'body-metrics@fittrack.vn',
      'FitTrack123!',
    );
    expect(registered, isTrue);
    return state;
  }

  test('accepts inclusive height and weight boundaries', () async {
    final state = await createCleanAccount();

    await state.updateBodyMetrics(heightCm: 100, weightKg: 0.1);
    await state.updateBodyMetrics(heightCm: 250, weightKg: 500);

    expect(state.weightEntries, hasLength(2));
    expect(state.profile.heightCm, 250);
    expect(state.profile.currentWeightKg, 500);
  });

  test('rejects height outside 100 to 250 centimeters', () async {
    final state = await createCleanAccount();

    await expectLater(
      state.updateBodyMetrics(heightCm: 99.9, weightKg: 65),
      throwsArgumentError,
    );
    await expectLater(
      state.updateBodyMetrics(heightCm: 250.1, weightKg: 65),
      throwsArgumentError,
    );

    expect(state.weightEntries, isEmpty);
  });

  test('rejects non-positive weight and weight above 500 kilograms', () async {
    final state = await createCleanAccount();

    for (final invalidWeight in [0.0, -1.0, 500.1]) {
      await expectLater(
        state.updateBodyMetrics(heightCm: 170, weightKg: invalidWeight),
        throwsArgumentError,
      );
    }

    expect(state.weightEntries, isEmpty);
  });

  test(
    'rejects a measurement recorded in the future without mutation',
    () async {
      final state = await createCleanAccount();
      final originalProfile = state.profile;

      await expectLater(
        state.updateBodyMetrics(
          heightCm: 170,
          weightKg: 65,
          recordedAt: DateTime.now().add(const Duration(minutes: 5)),
        ),
        throwsArgumentError,
      );

      expect(state.weightEntries, isEmpty);
      expect(state.profile.heightCm, originalProfile.heightCm);
      expect(state.profile.currentWeightKg, originalProfile.currentWeightKg);
    },
  );

  test('calculates current BMI from the latest submitted metrics', () async {
    final state = await createCleanAccount();
    final now = DateTime.now();

    await state.updateBodyMetrics(
      heightCm: 170,
      weightKg: 65,
      recordedAt: now.subtract(const Duration(days: 1)),
    );
    await state.updateBodyMetrics(heightCm: 170, weightKg: 64, recordedAt: now);

    expect(state.latestWeight?.weightKg, 64);
    expect(state.profile.bmi, closeTo(22.15, 0.01));
  });

  test('keeps historical BMI stable with a height snapshot', () async {
    final state = await createCleanAccount();
    final now = DateTime.now();

    await state.updateBodyMetrics(
      heightCm: 170,
      weightKg: 65,
      recordedAt: now.subtract(const Duration(days: 1)),
    );
    await state.updateBodyMetrics(heightCm: 180, weightKg: 80, recordedAt: now);

    final olderEntry = state.weightEntries
        .where((entry) => entry.weightKg == 65)
        .single;
    expect(olderEntry.heightCm, 170);
    expect(olderEntry.bmi, closeTo(22.49, 0.01));
  });

  test('metric and imperial conversions round-trip accurately', () {
    const imperial = MeasurementUnitSystem.imperial;

    final inches = imperial.heightFromCentimeters(170);
    final pounds = imperial.weightFromKilograms(65);

    expect(imperial.heightToCentimeters(inches), closeTo(170, 0.001));
    expect(imperial.weightToKilograms(pounds), closeTo(65, 0.001));
  });

  test('body metrics survive local sign-out and sign-in', () async {
    final state = await createCleanAccount();

    await state.updateBodyMetrics(heightCm: 172, weightKg: 68);
    await state.signOut();
    final signedIn = await state.signIn(
      'body-metrics@fittrack.vn',
      'FitTrack123!',
    );

    expect(signedIn, isTrue);
    expect(state.profile.heightCm, 172);
    expect(state.profile.currentWeightKg, 68);
    expect(state.latestWeight?.weightKg, 68);
  });
}
