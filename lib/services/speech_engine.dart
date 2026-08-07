import 'speech_cue_service.dart';

abstract interface class SpeechEngine {
  Future<void> speak(
    String cue, {
    double rate = .48,
    String language = 'vi-VN',
  });

  Future<void> stop();
}

class DefaultSpeechEngine implements SpeechEngine {
  const DefaultSpeechEngine([this._service = const SpeechCueService()]);

  final SpeechCueService _service;

  @override
  Future<void> speak(
    String cue, {
    double rate = .48,
    String language = 'vi-VN',
  }) =>
      _service.speak(cue, rate: rate, language: language);

  @override
  Future<void> stop() => _service.stop();
}
