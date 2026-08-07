import 'package:fittrack/widgets/camera_coach_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only the exact squat exercise id supports Camera AI', () {
    expect(CameraCoachPanel.supportsExercise('squat'), isTrue);
    expect(CameraCoachPanel.supportsExercise('squat_bodyweight'), isFalse);
    expect(CameraCoachPanel.supportsExercise('ex-squat'), isFalse);
    expect(CameraCoachPanel.supportsExercise('fedb_Bodyweight_Squat'), isFalse);
    expect(CameraCoachPanel.supportsExercise('squat-nhay'), isFalse);
  });

  testWidgets('camera unavailability never switches mode automatically', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      var fallbackRequests = 0;
      var unavailableEvents = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraCoachPanel(
              targetReps: 10,
              requireUserStart: false,
              onUnavailable: (_) => unavailableEvents++,
              onFallbackRequested: () => fallbackRequests++,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(unavailableEvents, 1);
      expect(fallbackRequests, 0);
      expect(find.text('Camera Coach chưa khả dụng'), findsOneWidget);
      expect(find.text('Thử lại Camera Coach'), findsOneWidget);
      expect(find.text('Chuyển sang Hướng dẫn'), findsOneWidget);

      await tester.tap(find.text('Chuyển sang Hướng dẫn'));
      await tester.pump();

      expect(fallbackRequests, 1);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
