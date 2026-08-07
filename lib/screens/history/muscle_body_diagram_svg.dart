import 'package:flutter/material.dart';
import 'package:flutter_body_part_selector/flutter_body_part_selector.dart' as body;

import '../../services/workout_insights.dart';
import '../../theme/app_colors.dart';

Color muscleLevelColor(MuscleActivityLevel level) => switch (level) {
  MuscleActivityLevel.neutral => AppColors.textMuted,
  MuscleActivityLevel.low => AppColors.accent,
  MuscleActivityLevel.medium => AppColors.success,
  MuscleActivityLevel.high => AppColors.warning,
};

String muscleLevelLabel(MuscleActivityLevel level) => switch (level) {
  MuscleActivityLevel.neutral => 'Chưa có dữ liệu',
  MuscleActivityLevel.low => 'Thấp',
  MuscleActivityLevel.medium => 'Trung bình',
  MuscleActivityLevel.high => 'Cao',
};

/// Maps the app's broad regions to the real, individually tappable SVG paths
/// provided by `flutter_body_part_selector`, the same approach used by
/// MinhThang's muscle-balance screen.
const Map<MuscleRegion, List<body.Muscle>> _svgRegions = {
  MuscleRegion.chest: [body.Muscle.chestLeft, body.Muscle.chestRight],
  MuscleRegion.core: [body.Muscle.abs],
  MuscleRegion.shoulders: [body.Muscle.deltsLeft, body.Muscle.deltsRight],
  MuscleRegion.biceps: [body.Muscle.bicepsLeft, body.Muscle.bicepsRight],
  MuscleRegion.triceps: [body.Muscle.tricepsLeft, body.Muscle.tricepsRight],
  MuscleRegion.forearms: [body.Muscle.forearmsLeft, body.Muscle.forearmsRight],
  MuscleRegion.quadriceps: [body.Muscle.quadsLeft, body.Muscle.quadsRight],
  MuscleRegion.calves: [body.Muscle.calvesLeft, body.Muscle.calvesRight],
  MuscleRegion.upperBack: [body.Muscle.latsBackLeft, body.Muscle.latsBackRight],
  MuscleRegion.lowerBack: [
    body.Muscle.lowerLatsBackLeft,
    body.Muscle.lowerLatsBackRight,
  ],
  MuscleRegion.glutes: [body.Muscle.glutesLeft, body.Muscle.glutesRight],
  MuscleRegion.hamstrings: [
    body.Muscle.hamstringsLeft,
    body.Muscle.hamstringsRight,
  ],
};

bool _isFrontOnlyRegion(MuscleRegion region) => const {
  MuscleRegion.chest,
  MuscleRegion.core,
  MuscleRegion.biceps,
  MuscleRegion.forearms,
  MuscleRegion.quadriceps,
  MuscleRegion.calves,
}.contains(region);

bool _isBackOnlyRegion(MuscleRegion region) => const {
  MuscleRegion.triceps,
  MuscleRegion.upperBack,
  MuscleRegion.lowerBack,
  MuscleRegion.glutes,
  MuscleRegion.hamstrings,
}.contains(region);

bool _isVisibleOnView(MuscleRegion region, bool isFront) =>
    region == MuscleRegion.shoulders ||
    (isFront ? _isFrontOnlyRegion(region) : _isBackOnlyRegion(region));

final Map<body.Muscle, MuscleRegion> _reverseSvgRegionsFront = {
  for (final entry in _svgRegions.entries)
    if (_isVisibleOnView(entry.key, true))
      for (final svgMuscle in entry.value) svgMuscle: entry.key,
};

final Map<body.Muscle, MuscleRegion> _reverseSvgRegionsBack = {
  for (final entry in _svgRegions.entries)
    if (_isVisibleOnView(entry.key, false))
      for (final svgMuscle in entry.value) svgMuscle: entry.key,
};

/// Real anatomical front/back illustration with tappable SVG muscle paths.
/// The three layers allow low, medium, and high activity regions to be shown
/// simultaneously, because the package accepts one highlight color per
/// widget instance.
class MuscleBodyDiagram extends StatefulWidget {
  const MuscleBodyDiagram({
    super.key,
    required this.byRegion,
    required this.onTapRegion,
  });

  final Map<MuscleRegion, MuscleActivitySummary> byRegion;
  final ValueChanged<MuscleRegion> onTapRegion;

  @override
  State<MuscleBodyDiagram> createState() => _MuscleBodyDiagramState();
}

class _MuscleBodyDiagramState extends State<MuscleBodyDiagram> {
  var _isFront = true;

  Set<body.Muscle> _svgMusclesAtLevel(MuscleActivityLevel level) {
    final selected = <body.Muscle>{};
    for (final entry in _svgRegions.entries) {
      if (!_isVisibleOnView(entry.key, _isFront)) continue;
      if (widget.byRegion[entry.key]?.level == level) {
        selected.addAll(entry.value);
      }
    }
    return selected;
  }

  void _handleTap(body.Muscle svgMuscle) {
    final reverse = _isFront ? _reverseSvgRegionsFront : _reverseSvgRegionsBack;
    final region = reverse[svgMuscle];
    if (region != null) widget.onTapRegion(region);
  }

  @override
  Widget build(BuildContext context) {
    const levels = [
      MuscleActivityLevel.low,
      MuscleActivityLevel.medium,
      MuscleActivityLevel.high,
    ];
    return Column(
      children: [
        AspectRatio(
          // The package SVGs are approximately 337x946 / 353x935.
          aspectRatio: .37,
          child: Stack(
            children: [
              for (var index = 0; index < levels.length; index++)
                body.InteractiveBodySvg(
                  isFront: _isFront,
                  selectedMuscles: _svgMusclesAtLevel(levels[index]),
                  highlightColor: muscleLevelColor(levels[index]).withValues(
                    alpha: .82,
                  ),
                  // Only the top layer handles taps; hit testing still uses
                  // the underlying SVG paths for every body region.
                  enableSelection: index == levels.length - 1,
                  onMuscleTap: index == levels.length - 1 ? _handleTap : null,
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: () => setState(() => _isFront = !_isFront),
          icon: const Icon(Icons.flip_camera_android_outlined),
          label: Text(
            _isFront
                ? 'Mặt trước · Bấm để xem lưng'
                : 'Mặt sau · Bấm để xem trước',
          ),
        ),
      ],
    );
  }
}

class MuscleDiagramLegend extends StatelessWidget {
  const MuscleDiagramLegend({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 14,
    runSpacing: 6,
    children: [
      for (final level in MuscleActivityLevel.values)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: muscleLevelColor(level),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(muscleLevelLabel(level), style: const TextStyle(fontSize: 12)),
          ],
        ),
    ],
  );
}
