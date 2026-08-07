import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack/services/repetition_cue_scheduler.dart';

void main() {
  group('RepetitionCueScheduler', () {
    test('initializes cleanly at rep 0, phase up', () {
      final scheduler = RepetitionCueScheduler(
        targetReps: 10,
        tempoUp: 2,
        tempoHold: 1,
        tempoDown: 2,
      );

      expect(scheduler.completedReps, 0);
      expect(scheduler.currentRepIndex, 0);
      expect(scheduler.currentPhase, RepetitionPhase.up);
      expect(scheduler.currentPhaseCueLabel, '1');
      expect(scheduler.isCompleted, false);
    });

    test('ticks through tempo phases correctly', () {
      final scheduler = RepetitionCueScheduler(
        targetReps: 2,
        tempoUp: 2,
        tempoHold: 1,
        tempoDown: 2,
      );

      // t=0s: Up phase (2s)
      expect(scheduler.currentPhase, RepetitionPhase.up);
      expect(scheduler.currentPhaseCueLabel, '1');

      // tick 2000ms -> transitions to hold
      scheduler.tick(2000);
      expect(scheduler.currentPhase, RepetitionPhase.hold);
      expect(scheduler.currentPhaseCueLabel, '');

      // tick 1000ms -> transitions to down
      scheduler.tick(1000);
      expect(scheduler.currentPhase, RepetitionPhase.down);
      expect(scheduler.currentPhaseCueLabel, '2');

      // tick 2000ms -> finishes rep 1, starts rep 2 up phase
      scheduler.tick(2000);
      expect(scheduler.completedReps, 1);
      expect(scheduler.currentRepIndex, 1);
      expect(scheduler.currentPhase, RepetitionPhase.up);
      expect(scheduler.currentPhaseCueLabel, '1');
      expect(scheduler.isCompleted, false);

      // tick through rep 2: 2s up + 1s hold + 2s down
      scheduler.tick(2000);
      scheduler.tick(1000);
      scheduler.tick(2000);

      expect(scheduler.completedReps, 2);
      expect(scheduler.isCompleted, true);
    });

    test('pause preserves remaining phase duration', () {
      final scheduler = RepetitionCueScheduler(
        targetReps: 5,
        tempoUp: 2,
        tempoHold: 1,
        tempoDown: 2,
      );

      scheduler.tick(1000); // 1s into 2s Up phase
      expect(scheduler.remainingPhaseMs, 1000);

      scheduler.pause();
      expect(scheduler.isPaused, true);

      // ticking while paused does nothing
      final changed = scheduler.tick(1000);
      expect(changed, false);
      expect(scheduler.remainingPhaseMs, 1000);

      scheduler.resume();
      expect(scheduler.isPaused, false);
      scheduler.tick(1000);
      expect(scheduler.currentPhase, RepetitionPhase.hold);
    });

    test('repeatBeat resets current phase duration without resetting completedReps', () {
      final scheduler = RepetitionCueScheduler(
        targetReps: 5,
        tempoUp: 2,
        tempoHold: 1,
        tempoDown: 2,
      );

      // Complete rep 1 (5 x 1000ms ticks)
      for (var i = 0; i < 5; i++) {
        scheduler.tick(1000);
      }
      expect(scheduler.completedReps, 1);
      expect(scheduler.currentRepIndex, 1);

      // 1s into rep 2 up phase
      scheduler.tick(1000);
      expect(scheduler.remainingPhaseMs, 1000);

      // Repeat beat
      scheduler.repeatBeat();
      expect(scheduler.remainingPhaseMs, 2000);
      expect(scheduler.completedReps, 1);
      expect(scheduler.currentRepIndex, 1);
    });

    test('completeEarly returns completedReps and marks scheduler completed', () {
      final scheduler = RepetitionCueScheduler(
        targetReps: 10,
        tempoUp: 2,
        tempoHold: 1,
        tempoDown: 2,
      );

      // Complete 3 reps (15 x 1000ms ticks)
      for (var i = 0; i < 15; i++) {
        scheduler.tick(1000);
      }
      expect(scheduler.completedReps, 3);

      // Mid-way through rep 4 (2 ticks into up phase)
      scheduler.tick(1000);
      scheduler.tick(1000);
      expect(scheduler.currentRepIndex, 3);

      // Complete early
      final actualReps = scheduler.completeEarly();
      expect(actualReps, 3); // Rep 4 was not completed!
      expect(scheduler.isCompleted, true);
    });
  });
}
