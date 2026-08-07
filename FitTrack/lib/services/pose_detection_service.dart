import '../models/pose_coach.dart';

/// Boundary between a camera/ML implementation and FitTrack's pose logic.
///
/// [TInput] is owned by the platform adapter. Implementations must treat it as
/// transient and return only normalized landmarks in [PoseDetectionResult].
abstract interface class PoseDetectionService<TInput extends Object> {
  Future<PoseDetectionCapability> checkCapability();

  Future<PoseDetectionResult> detect(
    TInput input, {
    required DateTime capturedAt,
  });

  Future<void> dispose();
}

/// Reusable base for Android detector adapters. It drops a new inference while
/// another one is in flight, as required for a realtime camera stream.
abstract class SingleInferencePoseDetectionService<TInput extends Object>
    implements PoseDetectionService<TInput> {
  bool _isInferenceInFlight = false;
  bool _isDisposed = false;

  bool get isInferenceInFlight => _isInferenceInFlight;

  @override
  Future<PoseDetectionResult> detect(
    TInput input, {
    required DateTime capturedAt,
  }) async {
    if (_isDisposed) {
      return PoseDetectionResult.unavailable(
        capturedAt,
        PoseCapabilityUnavailableReason.disposed,
      );
    }
    if (_isInferenceInFlight) {
      return PoseDetectionResult.busy(capturedAt);
    }

    _isInferenceInFlight = true;
    try {
      final capability = await checkCapability();
      if (!capability.isAvailable) {
        return PoseDetectionResult.unavailable(
          capturedAt,
          capability.unavailableReason,
        );
      }
      return await performDetection(input, capturedAt: capturedAt);
    } catch (_) {
      return PoseDetectionResult.failure(
        capturedAt,
        errorCode: 'pose_detection_failed',
      );
    } finally {
      _isInferenceInFlight = false;
    }
  }

  /// Implement this in a camera/ML Kit adapter. Do not retain [input] after the
  /// returned future completes.
  Future<PoseDetectionResult> performDetection(
    TInput input, {
    required DateTime capturedAt,
  });

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await disposeDetector();
  }

  Future<void> disposeDetector() async {}
}

/// Safe fallback for Web, unsupported devices, and builds without a detector.
/// It never reads or retains the supplied input.
final class UnavailablePoseDetectionService<TInput extends Object>
    implements PoseDetectionService<TInput> {
  const UnavailablePoseDetectionService(this._capability);

  factory UnavailablePoseDetectionService.web() =>
      UnavailablePoseDetectionService<TInput>(
        PoseDetectionCapability.unavailable(
          PoseCapabilityUnavailableReason.web,
        ),
      );

  factory UnavailablePoseDetectionService.unsupportedPlatform() =>
      UnavailablePoseDetectionService<TInput>(
        PoseDetectionCapability.unavailable(
          PoseCapabilityUnavailableReason.unsupportedPlatform,
        ),
      );

  factory UnavailablePoseDetectionService.modelNotConfigured() =>
      UnavailablePoseDetectionService<TInput>(
        PoseDetectionCapability.unavailable(
          PoseCapabilityUnavailableReason.modelUnavailable,
        ),
      );

  final PoseDetectionCapability _capability;

  @override
  Future<PoseDetectionCapability> checkCapability() async => _capability;

  @override
  Future<PoseDetectionResult> detect(
    TInput input, {
    required DateTime capturedAt,
  }) async => PoseDetectionResult.unavailable(
    capturedAt,
    _capability.unavailableReason,
  );

  @override
  Future<void> dispose() async {}
}
