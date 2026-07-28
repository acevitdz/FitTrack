import 'package:fittrack/screens/onboarding/onboarding_screen.dart';
import 'package:fittrack/services/notification_service.dart';
import 'package:fittrack/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding previews BMI and a matching program', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      firebaseAvailable: false,
      notificationService: NotificationService(),
    );
    await state.initialize();

    await tester.pumpWidget(MaterialApp(home: OnboardingScreen(state: state)));
    await tester.pumpAndSettle();

    expect(find.text('Bắt đầu an toàn'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();

    expect(find.text('BMI tạm tính'), findsOneWidget);
    expect(find.text('23.5'), findsOneWidget);

    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('onboarding-program-preview')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Gợi ý chương trình'), findsOneWidget);
    expect(find.text('Nền tảng vận động tại nhà'), findsOneWidget);
    expect(find.text('Chọn chương trình'), findsOneWidget);
  });
}
