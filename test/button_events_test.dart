import 'package:fittrack/data/seed_data.dart';
import 'package:fittrack/models/active_workout.dart';
import 'package:fittrack/models/exercise.dart';
import 'package:fittrack/screens/exercises/exercise_library_screen.dart';
import 'package:fittrack/screens/health/weight_screen.dart';
import 'package:fittrack/screens/history/history_screen.dart';
import 'package:fittrack/screens/home/main_shell.dart';
import 'package:fittrack/screens/profile/profile_screen.dart';
import 'package:fittrack/screens/program/program_overview_screen.dart';
import 'package:fittrack/screens/home/home_screen.dart';
import 'package:fittrack/services/active_workout_draft_store.dart';
import 'package:fittrack/services/bundled_exercise_catalog.dart';
import 'package:fittrack/services/local_store.dart';
import 'package:fittrack/services/notification_service.dart';
import 'package:fittrack/state/app_state.dart';
import 'package:fittrack/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryStore extends LocalStore {
  Map<String, dynamic>? data;
  String? authenticatedUid = 'demo-user';

  @override
  Future<Map<String, dynamic>?> loadState() async => data;

  @override
  Future<void> saveState(Map<String, dynamic> value) async => data = value;

  @override
  Future<bool> loadAuthenticated() async => true;

  @override
  Future<void> saveAuthenticated(bool value) async {}

  @override
  Future<String?> loadAuthenticatedUid() async => authenticatedUid;

  @override
  Future<void> saveAuthenticatedUid(String? uid) async {
    authenticatedUid = uid;
  }

  @override
  Future<void> clear() async => data = null;
}

class _MemoryWorkoutDraftStore extends ActiveWorkoutDraftStore {
  final Map<String, ActiveWorkoutDraft> drafts = {};

  @override
  Future<ActiveWorkoutDraft?> load(String userId) async => drafts[userId];

  @override
  Future<void> save(String userId, ActiveWorkoutDraft draft) async {
    drafts[userId] = draft;
  }

  @override
  Future<bool> contains(String userId) async => drafts.containsKey(userId);

  @override
  Future<void> clear(String userId) async => drafts.remove(userId);
}

class _FakeNotifications extends NotificationService {
  @override
  Future<void> initialize() async {}
}

late List<Exercise> _testExerciseCatalog;

Future<AppState> _createState() async {
  final state = AppState(
    firebaseAvailable: false,
    notificationService: _FakeNotifications(),
    localStore: _MemoryStore(),
    workoutDraftStore: _MemoryWorkoutDraftStore(),
    testExerciseCatalog: _testExerciseCatalog,
  );
  await state.initialize();
  await state.ensureProgramEnrollment();
  return state;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(412, 915),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: screen));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi');
    _testExerciseCatalog = [
      ...SeedData.exercises,
      ...await const BundledExerciseCatalog().load(),
    ].map((exercise) => exercise.copyWith(imageUrl: '')).toList();
  });

  testWidgets(
    'main navigation opens only Today, Program, Progress and Profile',
    (tester) async {
      final state = await _createState();
      await _pumpScreen(tester, MainShell(state: state));

      expect(find.byType(HomeScreen), findsOneWidget);

      await tester.tap(find.text('Chương trình').last);
      await tester.pumpAndSettle();
      expect(find.byType(ProgramOverviewScreen), findsOneWidget);

      await tester.tap(find.text('Tiến độ').last);
      await tester.pumpAndSettle();
      expect(find.byType(HistoryScreen), findsOneWidget);

      await tester.tap(find.text('Hồ sơ').last);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);

      final bodyMetrics = find.text('Chỉ số cơ thể');
      await tester.ensureVisible(bodyMetrics);
      await tester.tap(bodyMetrics);
      await tester.pumpAndSettle();
      expect(find.byType(WeightScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trang chủ').last);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Tạo kế hoạch'), findsNothing);
      expect(find.text('Bài tập cá nhân'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile dialogs finish closing before profile or auth state changes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = await _createState();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 915);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        AnimatedBuilder(
          animation: state,
          builder: (context, _) => MaterialApp(
            key: ValueKey(state.isAuthenticated),
            theme: AppTheme.light,
            home: state.isAuthenticated
                ? Scaffold(body: ProfileScreen(state: state))
                : const Scaffold(body: Center(child: Text('Đã đăng xuất'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Sửa tên hiển thị'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Tên Kiểm Thử');
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();

      expect(state.profile.name, 'Tên Kiểm Thử');
      expect(tester.takeException(), isNull);

      final deleteButton = find.text('Xóa tài khoản');
      await tester.scrollUntilVisible(
        deleteButton,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'XÓA');
      await tester.pump();
      final confirmDelete = find.widgetWithText(FilledButton, 'Xóa tài khoản');
      expect(tester.widget<FilledButton>(confirmDelete).onPressed, isNotNull);
      await tester.tap(confirmDelete);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 2));
        while (state.isAuthenticated && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();

      expect(find.text('Xóa tài khoản và dữ liệu?'), findsNothing);

      expect(state.isAuthenticated, isFalse);
      expect(find.text('Đã đăng xuất'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'exercise library supports favorites but remains prescription read-only',
    (tester) async {
      final state = await _createState();
      final exercise = state.templateExercises.first;
      await _pumpScreen(tester, ExerciseLibraryScreen(state: state));

      await tester.enterText(find.byType(TextField).first, exercise.name);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final favorite = find.byTooltip('Yêu thích').first;
      await tester.ensureVisible(favorite);
      await tester.tap(favorite);
      await tester.pump();

      expect(state.favoriteExerciseIds, contains(exercise.id));
      expect(find.byTooltip('Bỏ yêu thích'), findsWidgets);
      expect(find.text('Thêm vào kế hoạch'), findsNothing);
      expect(find.text('Tạo bài tập cá nhân'), findsNothing);
      expect(find.textContaining('chỉ để xem'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
