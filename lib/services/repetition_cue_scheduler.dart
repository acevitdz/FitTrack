enum RepetitionPhase { up, hold, down }

class RepetitionCueScheduler {
  RepetitionCueScheduler({
    required this.targetReps,
    this.tempoUp = 2,
    this.tempoHold = 1,
    this.tempoDown = 2,
  })  : assert(targetReps > 0),
        assert(tempoUp >= 0),
        assert(tempoHold >= 0),
        assert(tempoDown >= 0) {
    _resetPhaseDuration();
  }

  final int targetReps;
  final int tempoUp;
  final int tempoHold;
  final int tempoDown;

  int _completedReps = 0;
  int _currentRepIndex = 0;
  RepetitionPhase _currentPhase = RepetitionPhase.up;
  int _remainingPhaseMs = 0;
  bool _isPaused = false;
  bool _isCompleted = false;
  bool _isSkipped = false;
  bool _hasSpokenCurrentPhaseCue = false;

  int get completedReps => _completedReps;
  int get currentRepIndex => _currentRepIndex;
  RepetitionPhase get currentPhase => _currentPhase;
  int get remainingPhaseMs => _remainingPhaseMs;
  bool get isPaused => _isPaused;
  bool get isCompleted => _isCompleted;
  bool get isSkipped => _isSkipped;
  bool get hasSpokenCurrentPhaseCue => _hasSpokenCurrentPhaseCue;

  int get totalRepTempoSeconds => tempoUp + tempoHold + tempoDown;
  int get totalEstimatedWorkSeconds => targetReps * totalRepTempoSeconds;

  void markPhaseCueSpoken() {
    _hasSpokenCurrentPhaseCue = true;
  }

  String get currentPhaseCueLabel {
    switch (_currentPhase) {
      case RepetitionPhase.up:
        return '1';
      case RepetitionPhase.hold:
        return '';
      case RepetitionPhase.down:
        return '2';
    }
  }

  String get currentPhaseUiLabel {
    switch (_currentPhase) {
      case RepetitionPhase.up:
        return 'Nâng / Đẩy';
      case RepetitionPhase.hold:
        return 'Giữ';
      case RepetitionPhase.down:
        return 'Hạ xuống';
    }
  }

  void _resetPhaseDuration() {
    final seconds = switch (_currentPhase) {
      RepetitionPhase.up => tempoUp,
      RepetitionPhase.hold => tempoHold,
      RepetitionPhase.down => tempoDown,
    };
    _remainingPhaseMs = seconds * 1000;
    _hasSpokenCurrentPhaseCue = false;
  }

  bool tick(int elapsedMs) {
    if (_isPaused || _isCompleted || elapsedMs <= 0) return false;

    _remainingPhaseMs -= elapsedMs;
    if (_remainingPhaseMs > 0) return false;

    // Transition phase
    switch (_currentPhase) {
      case RepetitionPhase.up:
        if (tempoHold > 0) {
          _currentPhase = RepetitionPhase.hold;
        } else if (tempoDown > 0) {
          _currentPhase = RepetitionPhase.down;
        } else {
          _finishRep();
        }
        break;

      case RepetitionPhase.hold:
        if (tempoDown > 0) {
          _currentPhase = RepetitionPhase.down;
        } else {
          _finishRep();
        }
        break;

      case RepetitionPhase.down:
        _finishRep();
        break;
    }

    if (!_isCompleted) {
      _resetPhaseDuration();
    }
    return true;
  }

  void _finishRep() {
    _completedReps++;
    if (_completedReps >= targetReps) {
      _isCompleted = true;
    } else {
      _currentRepIndex = _completedReps;
      _currentPhase = RepetitionPhase.up;
    }
  }

  void pause() {
    _isPaused = true;
  }

  void resume() {
    _isPaused = false;
  }

  void repeatBeat() {
    _resetPhaseDuration();
  }

  int completeEarly() {
    _isCompleted = true;
    return _completedReps;
  }

  void skip() {
    _isCompleted = true;
    _isSkipped = true;
  }
}
