import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/pose_coach.dart';
import '../services/pose_detection_adapter.dart';
import '../theme/app_colors.dart';

typedef CameraCoachResultCallback = void Function(PoseCoachResult result);
typedef CameraCoachRepCallback = void Function(PoseRepEvent event);

/// Self-contained Android Camera Coach panel for the Squat MVP.
///
/// The parent Active Workout screen owns workout transitions. It can use
/// [onTargetReached] to complete the current guided set. Camera failures and
/// unreliable tracking never change workout mode automatically;
/// [onFallbackRequested] is called only from an explicit user action.
class CameraCoachPanel extends StatefulWidget {
  const CameraCoachPanel({
    super.key,
    required this.targetReps,
    required this.onFallbackRequested,
    this.exerciseId = 'squat',
    this.poseRuleVersionId = 'squat_pose_v1',
    this.initialRepCount = 0,
    this.poseRulePublished = true,
    this.deviceAllowed = true,
    this.requireUserStart = true,
    this.initialLensDirection = CameraLensDirection.front,
    this.unstableWarningDelay = const Duration(seconds: 5),
    this.ruleEngine,
    this.onResult,
    this.onRepCompleted,
    this.onUnavailable,
    this.onTargetReached,
  }) : assert(targetReps > 0),
       assert(initialRepCount >= 0);

  final String exerciseId;
  final String? poseRuleVersionId;
  final int targetReps;
  final int initialRepCount;
  final bool poseRulePublished;
  final bool deviceAllowed;
  final bool requireUserStart;
  final CameraLensDirection initialLensDirection;
  final Duration unstableWarningDelay;
  final SquatPoseRuleEngine? ruleEngine;
  final CameraCoachResultCallback? onResult;
  final CameraCoachRepCallback? onRepCompleted;
  final ValueChanged<PoseCapabilityUnavailableReason>? onUnavailable;
  final VoidCallback? onTargetReached;
  final VoidCallback onFallbackRequested;

  static bool supportsExercise(String exerciseId) {
    return exerciseId == 'squat';
  }

  static bool supportsRule(String exerciseId, String? ruleVersionId) =>
      supportsExercise(exerciseId) && ruleVersionId == 'squat_pose_v1';

  static bool get platformSupported =>
      MlKitPoseDetectionService.isAndroidSupported;

  @override
  State<CameraCoachPanel> createState() => _CameraCoachPanelState();
}

class _CameraCoachPanelState extends State<CameraCoachPanel>
    with WidgetsBindingObserver {
  late SquatPoseRuleEngine _ruleEngine;
  late CameraLensDirection _preferredLens;
  CameraController? _cameraController;
  MlKitPoseDetectionService? _detector;
  PoseCoachResult? _result;
  PoseCapabilityUnavailableReason? _unavailableReason;
  DateTime? _unreliableSince;
  int _sessionToken = 0;
  int _consecutiveFailures = 0;
  bool _initializing = true;
  bool _targetReachedNotified = false;
  bool _unavailableNotified = false;
  bool _unstableWarningNotified = false;
  late bool _userStarted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ruleEngine =
        widget.ruleEngine ??
        SquatPoseRuleEngine(initialRepCount: widget.initialRepCount);
    _preferredLens = widget.initialLensDirection;
    _userStarted = !widget.requireUserStart;
    if (_userStarted) unawaited(_initializeCamera());
  }

  @override
  void didUpdateWidget(covariant CameraCoachPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ruleEngine != null &&
        widget.ruleEngine != oldWidget.ruleEngine) {
      _ruleEngine = widget.ruleEngine!;
    }
    if (widget.targetReps != oldWidget.targetReps &&
        _ruleEngine.repCount < widget.targetReps) {
      _targetReachedNotified = false;
    }
    if (widget.exerciseId != oldWidget.exerciseId ||
        widget.poseRuleVersionId != oldWidget.poseRuleVersionId ||
        widget.poseRulePublished != oldWidget.poseRulePublished ||
        widget.deviceAllowed != oldWidget.deviceAllowed) {
      unawaited(_restartCamera());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_userStarted && _unavailableReason == null) {
        unawaited(_initializeCamera());
      }
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_releaseResources());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_releaseResources());
    super.dispose();
  }

  PoseCapabilityUnavailableReason? _gateReason() {
    if (!widget.poseRulePublished ||
        !CameraCoachPanel.supportsRule(
          widget.exerciseId,
          widget.poseRuleVersionId,
        )) {
      return PoseCapabilityUnavailableReason.exerciseUnsupported;
    }
    if (!widget.deviceAllowed) {
      return PoseCapabilityUnavailableReason.deviceUnsupported;
    }
    if (kIsWeb) return PoseCapabilityUnavailableReason.web;
    if (defaultTargetPlatform != TargetPlatform.android) {
      return PoseCapabilityUnavailableReason.unsupportedPlatform;
    }
    return null;
  }

  Future<void> _initializeCamera() async {
    if (_cameraController != null || !mounted) return;
    final gateReason = _gateReason();
    if (gateReason != null) {
      _activateFallback(gateReason);
      return;
    }

    final token = ++_sessionToken;
    if (mounted) {
      setState(() {
        _initializing = true;
        _unavailableReason = null;
      });
    }
    CameraController? pendingController;
    MlKitPoseDetectionService? pendingDetector;
    try {
      final cameras = await availableCameras();
      if (!mounted || token != _sessionToken) return;
      if (cameras.isEmpty) {
        _activateFallback(PoseCapabilityUnavailableReason.cameraUnavailable);
        return;
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == _preferredLens,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      pendingController = controller;
      await controller.initialize();
      if (!mounted || token != _sessionToken) {
        await controller.dispose();
        return;
      }

      final detector = MlKitPoseDetectionService(
        camera: camera,
        deviceOrientation: () => controller.value.deviceOrientation,
      );
      pendingDetector = detector;
      final capability = await detector.checkCapability();
      if (!capability.isAvailable) {
        await detector.dispose();
        await controller.dispose();
        _activateFallback(capability.unavailableReason);
        return;
      }

      _cameraController = controller;
      _detector = detector;
      pendingController = null;
      pendingDetector = null;
      await controller.startImageStream(
        (image) => unawaited(_processFrame(image, token)),
      );
      if (!mounted || token != _sessionToken) {
        await _releaseResources();
        return;
      }
      setState(() => _initializing = false);
    } on CameraException catch (error) {
      await pendingDetector?.dispose();
      await pendingController?.dispose();
      final permissionDenied =
          error.code == 'CameraAccessDenied' ||
          error.code == 'CameraAccessDeniedWithoutPrompt' ||
          error.code == 'CameraAccessRestricted';
      _activateFallback(
        permissionDenied
            ? PoseCapabilityUnavailableReason.permissionDenied
            : PoseCapabilityUnavailableReason.cameraUnavailable,
      );
    } catch (_) {
      await pendingDetector?.dispose();
      await pendingController?.dispose();
      _activateFallback(PoseCapabilityUnavailableReason.cameraUnavailable);
    }
  }

  Future<void> _processFrame(CameraImage image, int token) async {
    final detector = _detector;
    if (!mounted || token != _sessionToken || detector == null) return;
    final capturedAt = DateTime.now();
    final detection = await detector.detect(image, capturedAt: capturedAt);
    if (!mounted || token != _sessionToken) return;

    switch (detection.status) {
      case PoseDetectionStatus.busy:
        return;
      case PoseDetectionStatus.unavailable:
        _activateFallback(
          detection.unavailableReason ??
              PoseCapabilityUnavailableReason.modelUnavailable,
        );
        return;
      case PoseDetectionStatus.failure:
        _consecutiveFailures++;
        if (_consecutiveFailures >= 3) {
          _activateFallback(PoseCapabilityUnavailableReason.modelUnavailable);
        }
        return;
      case PoseDetectionStatus.noPose:
        _consecutiveFailures = 0;
        _publishResult(
          PoseCoachResult(
            status: PoseCoachStatus.notVisible,
            phase: _ruleEngine.phase,
            repCount: _ruleEngine.repCount,
            capturedAt: capturedAt,
            isCalibrated: _ruleEngine.isCalibrated,
            feedbackCode: PoseFeedbackCode.positionFullBody,
          ),
        );
        return;
      case PoseDetectionStatus.multiplePoses:
        _consecutiveFailures = 0;
        _publishResult(
          PoseCoachResult(
            status: PoseCoachStatus.notVisible,
            phase: _ruleEngine.phase,
            repCount: _ruleEngine.repCount,
            capturedAt: capturedAt,
            isCalibrated: _ruleEngine.isCalibrated,
            feedbackCode: PoseFeedbackCode.onePersonOnly,
          ),
        );
        return;
      case PoseDetectionStatus.detected:
        _consecutiveFailures = 0;
        final frame = detection.frame;
        if (frame == null) return;
        _publishResult(
          _ruleEngine.evaluate(frame, evaluatedAt: DateTime.now()),
        );
    }
  }

  void _publishResult(PoseCoachResult result) {
    if (!mounted) return;
    setState(() => _result = result);
    widget.onResult?.call(result);

    final repEvent = result.repEvent;
    if (repEvent != null) widget.onRepCompleted?.call(repEvent);
    if (!_targetReachedNotified && result.repCount >= widget.targetReps) {
      _targetReachedNotified = true;
      widget.onTargetReached?.call();
    }

    if (result.status == PoseCoachStatus.uncertain ||
        result.status == PoseCoachStatus.notVisible) {
      final now = DateTime.now();
      _unreliableSince ??= now;
      if (!_unstableWarningNotified &&
          now.difference(_unreliableSince!) >= widget.unstableWarningDelay) {
        _unstableWarningNotified = true;
        widget.onUnavailable?.call(
          PoseCapabilityUnavailableReason.trackingUnreliable,
        );
      }
    } else {
      _unreliableSince = null;
      _unstableWarningNotified = false;
    }
  }

  void _activateFallback(PoseCapabilityUnavailableReason reason) {
    if (!mounted) return;
    _sessionToken++;
    setState(() {
      _initializing = false;
      _unavailableReason = reason;
    });
    unawaited(_releaseResources(invalidateSession: false));
    if (_unavailableNotified) return;
    _unavailableNotified = true;
    widget.onUnavailable?.call(reason);
  }

  Future<void> _restartCamera() async {
    _userStarted = true;
    _unavailableReason = null;
    _unavailableNotified = false;
    _unstableWarningNotified = false;
    _unreliableSince = null;
    await _releaseResources();
    if (mounted) await _initializeCamera();
  }

  Future<void> _switchCamera() async {
    _preferredLens = _preferredLens == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    await _restartCamera();
  }

  Future<void> _releaseResources({bool invalidateSession = true}) async {
    if (invalidateSession) _sessionToken++;
    final controller = _cameraController;
    final detector = _detector;
    _cameraController = null;
    _detector = null;
    if (controller != null) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {
        // Camera may already be closing because of an app lifecycle change.
      }
      await controller.dispose();
    }
    if (detector != null) await detector.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_userStarted) return _preflightPanel(context);
    final reason = _unavailableReason;
    if (reason != null) return _fallbackPanel(context, reason);
    final controller = _cameraController;
    if (_initializing ||
        controller == null ||
        !controller.value.isInitialized) {
      return _loadingPanel(context);
    }
    return _cameraPanel(context, controller);
  }

  Widget _preflightPanel(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.camera_alt_outlined, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chuẩn bị Camera Coach',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Đặt điện thoại ổn định, đủ sáng và để toàn thân trong khung hình. '
          'Chỉ một người nên xuất hiện trước camera.',
        ),
        const SizedBox(height: 10),
        const Text(
          'Khung hình được xử lý tạm thời trên thiết bị. FitTrack không lưu '
          'ảnh, video hoặc landmark. AI có thể sai và bạn luôn có thể chuyển '
          'sang xác nhận có hướng dẫn.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              setState(() => _userStarted = true);
              unawaited(_initializeCamera());
            },
            icon: const Icon(Icons.videocam_outlined),
            label: const Text('Bắt đầu Camera Coach'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: widget.onFallbackRequested,
            child: const Text('Chuyển sang Hướng dẫn'),
          ),
        ),
      ],
    ),
  );

  Widget _loadingPanel(BuildContext context) => Container(
    height: 340,
    decoration: BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 14),
          Text(
            'Đang chuẩn bị Camera Coach…',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    ),
  );

  Widget _fallbackPanel(
    BuildContext context,
    PoseCapabilityUnavailableReason reason,
  ) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.videocam_off_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          'Camera Coach chưa khả dụng',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(_fallbackMessage(reason), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _restartCamera,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại Camera Coach'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.onFallbackRequested,
            icon: const Icon(Icons.touch_app_outlined),
            label: const Text('Chuyển sang Hướng dẫn'),
          ),
        ),
      ],
    ),
  );

  Widget _cameraPanel(BuildContext context, CameraController controller) {
    final result = _result;
    final statusColor = switch (result?.status) {
      PoseCoachStatus.good => const Color(0xFF1B8A5A),
      PoseCoachStatus.needsCue => const Color(0xFFF59E0B),
      PoseCoachStatus.notVisible => const Color(0xFF64748B),
      PoseCoachStatus.uncertain => const Color(0xFFDC2626),
      null => const Color(0xFF2563EB),
    };
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    var previewRatio = controller.value.aspectRatio;
    if (previewRatio <= 0) {
      previewRatio = 3 / 4;
    } else if (isPortrait && previewRatio > 1) {
      previewRatio = 1 / previewRatio;
    } else if (!isPortrait && previewRatio < 1) {
      previewRatio = 1 / previewRatio;
    }

    final previewSize = controller.value.previewSize;
    final previewWidth = previewSize != null
        ? (isPortrait ? previewSize.height : previewSize.width)
        : 3.0;
    final previewHeight = previewSize != null
        ? (isPortrait ? previewSize.width : previewSize.height)
        : 4.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: previewRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: previewWidth,
                  height: previewHeight,
                  child: CameraPreview(controller),
                ),
              ),
              const IgnorePointer(child: _BodyGuideOverlay()),
              Positioned(
                top: 12,
                left: 12,
                child: _StatusChip(
                  color: statusColor,
                  label: _statusLabel(result),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Đổi camera',
                      onPressed: _switchCamera,
                      icon: const Icon(Icons.cameraswitch_outlined),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      tooltip: 'Tắt camera',
                      onPressed: () => _activateFallback(
                        PoseCapabilityUnavailableReason.none,
                      ),
                      icon: const Icon(Icons.videocam_off_outlined),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: statusColor,
                          foregroundColor: Colors.white,
                          child: Text('${result?.repCount ?? 0}'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${result?.repCount ?? 0}/${widget.targetReps} lần',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _feedbackLabel(result),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(PoseCoachResult? result) => switch (result?.status) {
    PoseCoachStatus.good => 'Tốt — giữ nhịp',
    PoseCoachStatus.needsCue => 'Cần điều chỉnh',
    PoseCoachStatus.notVisible => 'Chưa thấy rõ',
    PoseCoachStatus.uncertain => 'Không chắc chắn',
    null => 'Đang định vị',
  };

  String _feedbackLabel(PoseCoachResult? result) {
    if (result == null) return 'Đưa toàn thân vào khung hình';
    return switch (result.feedbackCode) {
      PoseFeedbackCode.positionFullBody => 'Đưa toàn thân vào khung hình',
      PoseFeedbackCode.lowConfidence => 'Giữ yên và tăng ánh sáng',
      PoseFeedbackCode.staleFrame => 'AI chưa theo kịp chuyển động',
      PoseFeedbackCode.standTall => 'Đứng thẳng để bắt đầu',
      PoseFeedbackCode.lowerHips => 'Hạ thấp thêm',
      PoseFeedbackCode.onePersonOnly => 'Chỉ để một người trong khung hình',
      PoseFeedbackCode.detectorUnavailable => 'Camera Coach chưa khả dụng',
      null => _phaseLabel(result.phase),
    };
  }

  String _phaseLabel(SquatPhase phase) => switch (phase) {
    SquatPhase.standing => 'Sẵn sàng',
    SquatPhase.descending => 'Hạ người có kiểm soát',
    SquatPhase.bottom => 'Độ sâu tốt',
    SquatPhase.ascending => 'Đứng lên và giữ nhịp',
  };

  String _fallbackMessage(
    PoseCapabilityUnavailableReason reason,
  ) => switch (reason) {
    PoseCapabilityUnavailableReason.web =>
      'Camera Coach chưa hỗ trợ trên Web. Chế độ sẽ không tự thay đổi.',
    PoseCapabilityUnavailableReason.unsupportedPlatform =>
      'Camera Coach hiện chỉ hỗ trợ Android.',
    PoseCapabilityUnavailableReason.exerciseUnsupported =>
      'Bài tập này chưa có pose rule được hỗ trợ.',
    PoseCapabilityUnavailableReason.deviceUnsupported =>
      'Thiết bị này chưa nằm trong danh sách hỗ trợ.',
    PoseCapabilityUnavailableReason.permissionDenied =>
      'Bạn chưa cấp quyền camera. Hãy cấp quyền rồi thử lại.',
    PoseCapabilityUnavailableReason.cameraUnavailable =>
      'Không thể mở camera trên thiết bị này.',
    PoseCapabilityUnavailableReason.modelUnavailable =>
      'Bộ nhận diện đang gặp lỗi. Bạn có thể thử lại Camera Coach.',
    PoseCapabilityUnavailableReason.trackingUnreliable =>
      'Không thể theo dõi tư thế ổn định. Hãy kiểm tra ánh sáng và vị trí camera.',
    PoseCapabilityUnavailableReason.disposed => 'Camera Coach đã dừng.',
    PoseCapabilityUnavailableReason.none =>
      'Camera đã tắt. Bạn có thể thử lại hoặc tự chọn chuyển sang Hướng dẫn.',
  };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _BodyGuideOverlay extends StatelessWidget {
  const _BodyGuideOverlay();

  @override
  Widget build(BuildContext context) => Center(
    child: FractionallySizedBox(
      widthFactor: .52,
      heightFactor: .72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white70, width: 2),
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    ),
  );
}
