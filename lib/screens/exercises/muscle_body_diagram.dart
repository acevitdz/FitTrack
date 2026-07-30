import 'package:flutter/material.dart';
import 'package:flutter_body_part_selector/flutter_body_part_selector.dart' as body;

import '../../domain/muscle_balance_calculator.dart';
import '../../models/exercise_enums.dart';
import '../../theme/app_colors.dart';

Color levelColor(MuscleVolumeLevel level) => switch (level) {
  MuscleVolumeLevel.neutral => AppColors.textMuted,
  MuscleVolumeLevel.low => AppColors.accent,
  MuscleVolumeLevel.medium => AppColors.success,
  MuscleVolumeLevel.high => AppColors.warning,
};

String levelLabel(MuscleVolumeLevel level) => switch (level) {
  MuscleVolumeLevel.neutral => 'Chưa có dữ liệu',
  MuscleVolumeLevel.low => 'Thấp',
  MuscleVolumeLevel.medium => 'Trung bình',
  MuscleVolumeLevel.high => 'Cao',
};

/// Maps our 13 detailed [Muscle] values to the real anatomical illustration
/// bundled with the `flutter_body_part_selector` package (MIT-licensed,
/// front.svg + back.svg with individually tappable muscle paths — see
/// pubspec.yaml).
///
/// This is based on the actual `<path id="...">` elements in the two SVG
/// files (checked directly), not the package's own `Muscle` enum grouping —
/// that enum's "front body"/"back body" source comment is misleading: e.g.
/// `triceps_left/right` only exists in body_back.svg despite being listed
/// under "front body" in the enum, and `delts_left/right` exists in BOTH
/// files (front = anterior delt, back = rear delt — same id, different
/// drawing depending on which SVG is loaded). So vai_truoc and vai_sau both
/// map to deltsLeft/deltsRight below; which one is meant is resolved by
/// which view is currently showing (see [_isFrontMuscle] / [_handleTap]).
///
/// Only [Muscle.vaiGiua] (lateral/middle delt) has no equivalent — neither
/// view's illustration subdivides the deltoid a third way. It's still fully
/// selectable from the detail list below the diagram in
/// muscle_balance_screen.dart, just not tappable on the picture.
const Map<Muscle, List<body.Muscle>> _svgRegions = {
  Muscle.nguc: [body.Muscle.chestLeft, body.Muscle.chestRight],
  Muscle.bung: [body.Muscle.abs],
  Muscle.vaiTruoc: [body.Muscle.deltsLeft, body.Muscle.deltsRight],
  Muscle.tayTruoc: [body.Muscle.bicepsLeft, body.Muscle.bicepsRight],
  Muscle.duiTruoc: [body.Muscle.quadsLeft, body.Muscle.quadsRight],
  Muscle.bapChan: [body.Muscle.calvesLeft, body.Muscle.calvesRight],
  Muscle.vaiSau: [body.Muscle.deltsLeft, body.Muscle.deltsRight],
  Muscle.taySau: [body.Muscle.tricepsLeft, body.Muscle.tricepsRight],
  Muscle.lungTren: [body.Muscle.latsBackLeft, body.Muscle.latsBackRight],
  Muscle.lungDuoi: [body.Muscle.lowerLatsBackLeft, body.Muscle.lowerLatsBackRight],
  Muscle.mong: [body.Muscle.glutesLeft, body.Muscle.glutesRight],
  Muscle.duiSau: [body.Muscle.hamstringsLeft, body.Muscle.hamstringsRight],
};

/// True for the view (`isFront`) each mapped region actually lives on —
/// derived from the real SVG files, not something we choose.
bool _isFrontMuscle(Muscle muscle) => const {
  Muscle.nguc, Muscle.bung, Muscle.vaiTruoc, Muscle.tayTruoc, Muscle.duiTruoc,
  Muscle.bapChan,
}.contains(muscle);

/// deltsLeft/deltsRight are ambiguous on their own (vai_truoc on front,
/// vai_sau on back both use them), so the reverse lookup used for tap
/// resolution has to be scoped per view rather than one flat map.
final Map<body.Muscle, Muscle> _reverseSvgRegionsFront = {
  for (final entry in _svgRegions.entries)
    if (_isFrontMuscle(entry.key))
      for (final svgMuscle in entry.value) svgMuscle: entry.key,
};
final Map<body.Muscle, Muscle> _reverseSvgRegionsBack = {
  for (final entry in _svgRegions.entries)
    if (!_isFrontMuscle(entry.key))
      for (final svgMuscle in entry.value) svgMuscle: entry.key,
};

/// Real anatomical illustration (front + back), flippable, tapping a shape
/// opens that muscle's detail — built on `flutter_body_part_selector`
/// instead of a hand-drawn CustomPainter so the diagram looks like an actual
/// body rather than assembled blocks.
class MuscleBodyDiagram extends StatefulWidget {
  const MuscleBodyDiagram({
    super.key,
    required this.byMuscle,
    required this.onTapMuscle,
  });

  final Map<Muscle, MuscleVolumeSummary> byMuscle;
  final void Function(Muscle muscle) onTapMuscle;

  @override
  State<MuscleBodyDiagram> createState() => _MuscleBodyDiagramState();
}

class _MuscleBodyDiagramState extends State<MuscleBodyDiagram> {
  var _isFront = true;

  Set<body.Muscle> _svgMusclesAtLevel(MuscleVolumeLevel level) {
    final result = <body.Muscle>{};
    for (final entry in _svgRegions.entries) {
      if (_isFrontMuscle(entry.key) != _isFront) continue;
      if (widget.byMuscle[entry.key]!.level == level) result.addAll(entry.value);
    }
    return result;
  }

  void _handleTap(body.Muscle svgMuscle) {
    final reverse = _isFront ? _reverseSvgRegionsFront : _reverseSvgRegionsBack;
    final muscle = reverse[svgMuscle];
    if (muscle != null) widget.onTapMuscle(muscle);
  }

  @override
  Widget build(BuildContext context) {
    // Stacked so all 3 non-neutral levels can be colored at once — the
    // package only takes one highlightColor per widget instance. Any one
    // layer's tap handling works for the whole picture (it resolves taps by
    // parsing the underlying SVG's paths, independent of what that layer
    // happens to have selected), so only the top layer wires onMuscleTap.
    final levels = [MuscleVolumeLevel.low, MuscleVolumeLevel.medium, MuscleVolumeLevel.high];
    return Column(
      children: [
        AspectRatio(
          // Matches the bundled SVGs' real proportions (front.svg 337x946,
          // back.svg 353x935) — using a mismatched ratio here would letterbox
          // the picture and shrink the actual tappable drawing inside the box.
          aspectRatio: 0.37,
          child: Stack(
            children: [
              for (var i = 0; i < levels.length; i++)
                body.InteractiveBodySvg(
                  isFront: _isFront,
                  selectedMuscles: _svgMusclesAtLevel(levels[i]),
                  highlightColor: levelColor(levels[i]).withValues(alpha: .82),
                  enableSelection: i == levels.length - 1,
                  onMuscleTap: i == levels.length - 1 ? _handleTap : null,
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: () => setState(() => _isFront = !_isFront),
          icon: const Icon(Icons.flip_camera_android_outlined),
          label: Text(_isFront ? 'Mặt trước · Bấm để xem lưng' : 'Mặt sau · Bấm để xem trước'),
        ),
      ],
    );
  }
}

class BodyDiagramLegend extends StatelessWidget {
  const BodyDiagramLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final level in MuscleVolumeLevel.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: levelColor(level),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(levelLabel(level), style: const TextStyle(fontSize: 12)),
            ],
          ),
      ],
    );
  }
}
