import 'package:fittrack/models/pose_coach.dart';
import 'package:fittrack/services/pose_feedback_voice_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('speaks each identical Camera AI feedback only once per set', () {
    final gate = PoseFeedbackVoiceGate();

    expect(
      gate.shouldSpeak(
        setKey: '0:0',
        feedbackCode: PoseFeedbackCode.positionFullBody,
      ),
      isTrue,
    );
    expect(
      gate.shouldSpeak(
        setKey: '0:0',
        feedbackCode: PoseFeedbackCode.positionFullBody,
      ),
      isFalse,
    );
    expect(
      gate.shouldSpeak(setKey: '0:0', feedbackCode: PoseFeedbackCode.lowerHips),
      isTrue,
    );
    expect(
      gate.shouldSpeak(
        setKey: '0:0',
        feedbackCode: PoseFeedbackCode.positionFullBody,
      ),
      isFalse,
    );
  });

  test('allows feedback again for a new set or after reset', () {
    final gate = PoseFeedbackVoiceGate();

    expect(
      gate.shouldSpeak(
        setKey: '0:0',
        feedbackCode: PoseFeedbackCode.positionFullBody,
      ),
      isTrue,
    );
    expect(
      gate.shouldSpeak(
        setKey: '0:1',
        feedbackCode: PoseFeedbackCode.positionFullBody,
      ),
      isTrue,
    );

    gate.reset();
    expect(
      gate.shouldSpeak(
        setKey: '0:1',
        feedbackCode: PoseFeedbackCode.positionFullBody,
      ),
      isTrue,
    );
    expect(gate.shouldSpeak(setKey: '0:1', feedbackCode: null), isFalse);
  });
}
