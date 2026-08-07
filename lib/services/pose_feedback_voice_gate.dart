import '../models/pose_coach.dart';

/// Allows each Camera AI feedback sentence to be spoken once per active set.
///
/// Camera frames arrive continuously, so the same visual feedback can be
/// emitted many times. Visual feedback remains live, while voice guidance is
/// deduplicated until the user starts another set or the gate is reset.
class PoseFeedbackVoiceGate {
  String? _setKey;
  final Set<PoseFeedbackCode> _spokenCodes = <PoseFeedbackCode>{};

  bool shouldSpeak({
    required String setKey,
    required PoseFeedbackCode? feedbackCode,
  }) {
    if (_setKey != setKey) {
      _setKey = setKey;
      _spokenCodes.clear();
    }
    if (feedbackCode == null) return false;
    return _spokenCodes.add(feedbackCode);
  }

  void reset() {
    _setKey = null;
    _spokenCodes.clear();
  }
}
