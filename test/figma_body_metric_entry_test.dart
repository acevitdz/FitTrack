import 'package:fittrack/screens/health/figma_body_metric_entry_screen.dart';
import 'package:fittrack/services/notification_service.dart';
import 'package:fittrack/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('body metric entry follows the Figma card structure', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      firebaseAvailable: false,
      notificationService: NotificationService(),
    );
    await state.initialize();

    await tester.pumpWidget(
      MaterialApp(home: FigmaBodyMetricEntryScreen(state: state)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nhập cân nặng'), findsOneWidget);
    expect(find.textContaining('Cân nặng hiện tại'), findsOneWidget);
    expect(find.textContaining('BMI:'), findsOneWidget);
    expect(find.text('Ngày đo'), findsOneWidget);
    expect(find.text('Giờ đo'), findsOneWidget);
    expect(find.text('Thông tin chỉ số'), findsOneWidget);
    expect(find.text('Lưu cân nặng'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
