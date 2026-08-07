import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'speech_engine.dart';

/// Small platform adapter for Voice Coach.
///
/// Workout rules decide *what* may be spoken. This service only delivers an
/// already-approved cue and never generates coaching text.
class SpeechCueService implements SpeechEngine {
  const SpeechCueService();

  static const _channel = MethodChannel('fittrack/tts');

  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> speak(
    String cue, {
    double rate = .48,
    String language = 'vi-VN',
  }) async {
    if (kIsWeb || cue.trim().isEmpty) return;
    try {
      await _channel.invokeMethod<void>('speak', {
        'text': cue.trim(),
        'rate': rate.clamp(.2, .8),
        'language': language,
      });
    } on PlatformException {
      // Voice is optional; the visual guidance remains authoritative.
    } on MissingPluginException {
      // Keeps widget tests and unsupported platforms on the guided fallback.
    }
  }

  @override
  Future<void> stop() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // No-op fallback.
    } on MissingPluginException {
      // No-op fallback.
    }
  }
}
