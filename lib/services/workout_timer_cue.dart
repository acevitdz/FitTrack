enum WorkoutTimerCue { tick, finalCountdown }

/// Emits at most one cue for each visible timer second.
class WorkoutTimerCueTracker {
  int? _lastSecond;

  WorkoutTimerCue? next(int remainingSeconds) {
    if (remainingSeconds < 1 || remainingSeconds == _lastSecond) return null;
    _lastSecond = remainingSeconds;
    return remainingSeconds <= 3
        ? WorkoutTimerCue.finalCountdown
        : WorkoutTimerCue.tick;
  }

  void reset() => _lastSecond = null;
}
