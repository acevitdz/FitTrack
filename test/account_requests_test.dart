import 'package:fittrack/services/notification_service.dart';
import 'package:fittrack/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> createAuthenticatedState() async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      firebaseAvailable: false,
      notificationService: NotificationService(),
    );
    await state.initialize();
    final registered = await state.register(
      'Lê Tiến Hải',
      'account-request@fittrack.vn',
      'FitTrack123!',
    );
    expect(registered, isTrue);
    return state;
  }

  test('data export request keeps the current session', () async {
    final state = await createAuthenticatedState();

    await state.requestDataExport();

    expect(state.isAuthenticated, isTrue);
    expect(state.profile.email, 'account-request@fittrack.vn');
  });

  test(
    'account deletion request signs out and clears local account data',
    () async {
      final state = await createAuthenticatedState();
      final accountUid = state.uid;

      await state.requestAccountDeletion();

      expect(state.isAuthenticated, isFalse);
      expect(state.uid, 'demo-user');
      expect(state.profile.email, 'demo@fittrack.vn');

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('fittrack.authenticated'), isNull);
      expect(preferences.getString('fittrack.authenticated_uid'), isNull);
      expect(preferences.getString('fittrack.state.$accountUid'), isNull);
    },
  );
}
