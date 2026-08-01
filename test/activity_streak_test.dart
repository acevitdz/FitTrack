import 'package:fittrack/services/notification_service.dart';
import 'package:fittrack/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppState createState() => AppState(
    firebaseAvailable: false,
    notificationService: NotificationService(),
  );

  Future<AppState> createCleanAccount() async {
    SharedPreferences.setMockInitialValues({});
    final state = createState();
    await state.initialize();
    final registered = await state.register(
      'Người kiểm thử',
      'streak@fittrack.vn',
      'FitTrack123!',
    );
    expect(registered, isTrue);
    return state;
  }

  test('weight activity counts only once per calendar day', () async {
    final state = await createCleanAccount();
    final now = DateTime.now();

    await state.updateBodyMetrics(heightCm: 170, weightKg: 68, recordedAt: now);
    await state.updateBodyMetrics(
      heightCm: 170,
      weightKg: 67.8,
      recordedAt: now.add(const Duration(minutes: 1)),
    );

    expect(state.activeDays, hasLength(1));
    expect(state.currentStreak, 1);
    expect(state.longestStreak, 1);
  });

  test(
    'weight activity builds current and longest consecutive streak',
    () async {
      final state = await createCleanAccount();
      final now = DateTime.now();

      for (final daysAgo in [2, 1, 0]) {
        await state.updateBodyMetrics(
          heightCm: 170,
          weightKg: 68 - daysAgo / 10,
          recordedAt: now.subtract(Duration(days: daysAgo)),
        );
      }

      expect(state.currentStreak, 3);
      expect(state.longestStreak, 3);
    },
  );

  test('a missed day starts a new current streak', () async {
    final state = await createCleanAccount();
    final now = DateTime.now();

    await state.updateBodyMetrics(
      heightCm: 170,
      weightKg: 68,
      recordedAt: now.subtract(const Duration(days: 3)),
    );
    await state.updateBodyMetrics(
      heightCm: 170,
      weightKg: 67.9,
      recordedAt: now,
    );

    expect(state.currentStreak, 1);
    expect(state.longestStreak, 1);
  });

  test('weight streak survives sign-out and local sign-in', () async {
    final state = await createCleanAccount();
    final now = DateTime.now();

    await state.updateBodyMetrics(
      heightCm: 170,
      weightKg: 68,
      recordedAt: now.subtract(const Duration(days: 1)),
    );
    await state.updateBodyMetrics(
      heightCm: 170,
      weightKg: 67.9,
      recordedAt: now,
    );
    await state.signOut();

    final signedIn = await state.signIn('streak@fittrack.vn', 'FitTrack123!');

    expect(signedIn, isTrue);
    expect(state.currentStreak, 2);
    expect(state.longestStreak, 2);
    expect(state.activeDays, hasLength(2));
  });
}
