import 'package:fittrack/data/seed_data.dart';
import 'package:fittrack/models/active_workout.dart';
import 'package:fittrack/models/exercise.dart';
import 'package:fittrack/screens/home/main_shell.dart';
import 'package:fittrack/services/active_workout_draft_store.dart';
import 'package:fittrack/services/bundled_exercise_catalog.dart';
import 'package:fittrack/services/local_store.dart';
import 'package:fittrack/services/notification_service.dart';
import 'package:fittrack/state/app_state.dart';
import 'package:fittrack/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _ResponsiveStore extends LocalStore {
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

class _ResponsiveDraftStore extends ActiveWorkoutDraftStore {
  @override
  Future<ActiveWorkoutDraft?> load(String userId) async => null;

  @override
  Future<void> save(String userId, ActiveWorkoutDraft draft) async {}

  @override
  Future<bool> contains(String userId) async => false;

  @override
  Future<void> clear(String userId) async {}
}

class _ResponsiveNotifications extends NotificationService {
  @override
  Future<void> initialize() async {}
}

late List<Exercise> _testExerciseCatalog;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi');
    _testExerciseCatalog = [
      ...SeedData.exercises,
      ...await const BundledExerciseCatalog().load(),
    ];
  });

  for (final size in [const Size(360, 800), const Size(412, 915)]) {
    testWidgets('target navigation has no overflow at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final state = AppState(
        firebaseAvailable: false,
        notificationService: _ResponsiveNotifications(),
        localStore: _ResponsiveStore(),
        workoutDraftStore: _ResponsiveDraftStore(),
        testExerciseCatalog: _testExerciseCatalog,
      );
      await state.initialize();
      await state.ensureProgramEnrollment();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MainShell(state: state),
        ),
      );
      await tester.pumpAndSettle();
      _expectNoLayoutException(tester);

      for (final label in ['Chương trình', 'Tiến độ', 'Hồ sơ', 'Trang chủ']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        _expectNoLayoutException(tester);
      }

      expect(find.text('Kế hoạch'), findsNothing);
      expect(find.text('Bài tập cá nhân'), findsNothing);
    });
  }
}

void _expectNoLayoutException(WidgetTester tester) {
  final exception = tester.takeException();
  expect(
    exception,
    isNull,
    reason: exception is FlutterError
        ? exception.toStringDeep()
        : exception?.toString(),
  );
}
