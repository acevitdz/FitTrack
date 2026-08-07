import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack/services/speech_engine.dart';
import 'package:fittrack/services/voice_cue_service.dart';

class MockSpeechEngine implements SpeechEngine {
  final List<String> spokenCues = [];
  bool isStopped = false;

  @override
  Future<void> speak(
    String cue, {
    double rate = .48,
    String language = 'vi-VN',
  }) async {
    spokenCues.add(cue);
    isStopped = false;
  }

  @override
  Future<void> stop() async {
    isStopped = true;
  }
}

void main() {
  group('VoiceCueService', () {
    late MockSpeechEngine mockEngine;
    late VoiceCueService service;

    setUp(() {
      mockEngine = MockSpeechEngine();
      service = VoiceCueService(engine: mockEngine);
    });

    test('delivers speak call to engine', () async {
      await service.speak('Một');
      expect(mockEngine.spokenCues, ['Một']);
      expect(service.lastSpokenCue, 'Một');
    });

    test('cancels pending speech on cancelPendingSpeech()', () async {
      await service.speak('Một');
      await service.cancelPendingSpeech();
      expect(mockEngine.isStopped, true);
    });
  });
}
