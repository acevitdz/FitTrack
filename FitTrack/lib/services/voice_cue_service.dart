import 'speech_engine.dart';

class VoiceCueService {
  VoiceCueService({SpeechEngine? engine})
      : _engine = engine ?? const DefaultSpeechEngine();

  final SpeechEngine _engine;
  bool _isSpeaking = false;
  String? _lastSpokenCue;

  bool get isSpeaking => _isSpeaking;
  String? get lastSpokenCue => _lastSpokenCue;

  Future<void> speak(
    String cue, {
    double rate = .48,
    String language = 'vi-VN',
    bool force = false,
  }) async {
    final text = cue.trim();
    if (text.isEmpty) return;

    if (_isSpeaking && !force) {
      await cancelPendingSpeech();
    }

    _isSpeaking = true;
    _lastSpokenCue = text;
    try {
      await _engine.speak(text, rate: rate, language: language);
    } finally {
      _isSpeaking = false;
    }
  }

  Future<void> cancelPendingSpeech() async {
    _isSpeaking = false;
    await _engine.stop();
  }
}
