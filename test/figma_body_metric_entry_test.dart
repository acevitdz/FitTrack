import 'package:fittrack/screens/health/figma_body_metric_entry_screen.dart';
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
    return state;
  }

  testWidgets('body metric entry follows the Figma card structure', (
    tester,
  ) async {
    final state = await createState();

    await tester.pumpWidget(
      MaterialApp(home: FigmaBodyMetricEntryScreen(state: state)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nhập cân nặng'), findsOneWidget);
    expect(find.textContaining('Cân nặng hiện tại'), findsOneWidget);
    expect(find.textContaining('BMI:'), findsOneWidget);
    expect(find.text('Ngày đo'), findsOneWidget);
    expect(find.text('Giờ đo'), findsOneWidget);
    expect(find.text('Ghi chú'), findsOneWidget);
    expect(find.text('Vừa ngủ dậy'), findsOneWidget);
    expect(find.text('Sau khi tập'), findsOneWidget);
    expect(find.text('Trước bữa tối'), findsOneWidget);
    expect(find.text('Lưu cân nặng'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Thông tin chỉ số'), findsNothing);
  });

  testWidgets('quick note fills the measurement note field', (tester) async {
    final state = await createState();

    await tester.pumpWidget(
      MaterialApp(home: FigmaBodyMetricEntryScreen(state: state)),
    );
    await tester.pumpAndSettle();

    final quickNote = find.byKey(
      const Key('body_metric_quick_note_Sau khi tập'),
    );
    await tester.ensureVisible(quickNote);
    await tester.pumpAndSettle();
    await tester.tap(quickNote);
    await tester.pump();

    final field = tester.widget<TextFormField>(
      find.byKey(const Key('body_metric_note_field')),
    );
    expect(field.controller?.text, 'Sau khi tập');
  });
}
