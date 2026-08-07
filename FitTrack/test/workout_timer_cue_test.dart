import 'package:fittrack/services/workout_timer_cue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('timer uses ticks before distinct final-three-second beeps', () {
    final tracker = WorkoutTimerCueTracker();

    expect(tracker.next(5), WorkoutTimerCue.tick);
    expect(tracker.next(5), isNull);
    expect(tracker.next(4), WorkoutTimerCue.tick);
    expect(tracker.next(3), WorkoutTimerCue.finalCountdown);
    expect(tracker.next(3), isNull);
    expect(tracker.next(2), WorkoutTimerCue.finalCountdown);
    expect(tracker.next(1), WorkoutTimerCue.finalCountdown);
    expect(tracker.next(0), isNull);
  });

  test('reset allows the next timer phase to cue the same second', () {
    final tracker = WorkoutTimerCueTracker();

    expect(tracker.next(10), WorkoutTimerCue.tick);
    tracker.reset();
    expect(tracker.next(10), WorkoutTimerCue.tick);
  });
}
