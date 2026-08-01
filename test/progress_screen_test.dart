import 'package:fittrack/screens/history/progress_screen.dart';
import 'package:fittrack/services/notification_service.dart';
import 'package:fittrack/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('progress report renders from shared AppState', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      firebaseAvailable: false,
      notificationService: NotificationService(),
    );
    await state.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProgressScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Báo cáo hiệu suất'), findsOneWidget);
    expect(find.text('Số buổi'), findsOneWidget);
    expect(find.text('Xu hướng số hiệp'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Kỷ lục mới (PRs)'), findsOneWidget);
  });
}
