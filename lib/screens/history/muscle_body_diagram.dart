// Legacy hand-drawn fallback kept for reference. The active muscle map uses
// the anatomical SVG implementation in muscle_body_diagram_svg.dart.
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: .52,
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final x = details.localPosition.dx / constraints.maxWidth;
                final y = details.localPosition.dy / constraints.maxHeight;
                final region = _hitTest(x, y);
                if (region != null) widget.onTapRegion(region);
              },
              child: CustomPaint(
                painter: _MuscleBodyPainter(
                  isFront: _isFront,
                  byRegion: widget.byRegion,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: () => setState(() => _isFront = !_isFront),
          icon: const Icon(Icons.flip_camera_android_outlined),
          label: Text(
            _isFront ? 'Mặt trước · Xem lưng' : 'Mặt sau · Xem mặt trước',
          ),
        ),
      ],
    );
  }

  MuscleRegion? _hitTest(double x, double y) {
    if (x < .18 || x > .82 || y < .04 || y > .98) return null;
    if ((x < .32 || x > .68) && y < .38) {
      return _isFront ? MuscleRegion.biceps : MuscleRegion.triceps;
    }
    if (y < .23) return MuscleRegion.shoulders;
    if (y < .36) return _isFront ? MuscleRegion.chest : MuscleRegion.upperBack;
    if (y < .52) return _isFront ? MuscleRegion.core : MuscleRegion.lowerBack;
    if (y < .70) return _isFront ? MuscleRegion.quadriceps : MuscleRegion.glutes;
    return _isFront ? MuscleRegion.calves : MuscleRegion.hamstrings;
  }
}

class _MuscleBodyPainter extends CustomPainter {
  _MuscleBodyPainter({required this.isFront, required this.byRegion});

  final bool isFront;
  final Map<MuscleRegion, MuscleActivitySummary> byRegion;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 200;
    canvas.save();
    canvas.scale(scale, size.height / 380);
    final outline = Paint()
      ..color = AppColors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 / scale;
    final base = Paint()
      ..color = AppColors.input
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(100, 25), 18, base);
    canvas.drawCircle(const Offset(100, 25), 18, outline);
    final torso = RRect.fromRectAndRadius(
      const Rect.fromLTWH(66, 47, 68, 125),
      const Radius.circular(26),
    );
    canvas.drawRRect(torso, base);
    canvas.drawRRect(torso, outline);
    final shapes = [
      RRect.fromRectAndRadius(const Rect.fromLTWH(40, 57, 21, 115), const Radius.circular(10)),
      RRect.fromRectAndRadius(const Rect.fromLTWH(139, 57, 21, 115), const Radius.circular(10)),
      RRect.fromRectAndRadius(const Rect.fromLTWH(70, 168, 26, 190), const Radius.circular(13)),
      RRect.fromRectAndRadius(const Rect.fromLTWH(104, 168, 26, 190), const Radius.circular(13)),
    ];
    for (final shape in shapes) {
      canvas.drawRRect(shape, base);
      canvas.drawRRect(shape, outline);
    }

    if (isFront) {
      _drawRegion(canvas, MuscleRegion.shoulders, const Rect.fromLTWH(57, 53, 86, 26));
      _drawRegion(canvas, MuscleRegion.chest, const Rect.fromLTWH(72, 76, 56, 36));
      _drawRegion(canvas, MuscleRegion.biceps, const Rect.fromLTWH(40, 76, 21, 45));
      _drawRegion(canvas, MuscleRegion.biceps, const Rect.fromLTWH(139, 76, 21, 45));
      _drawRegion(canvas, MuscleRegion.core, const Rect.fromLTWH(78, 116, 44, 44));
      _drawRegion(canvas, MuscleRegion.quadriceps, const Rect.fromLTWH(70, 170, 26, 80));
      _drawRegion(canvas, MuscleRegion.quadriceps, const Rect.fromLTWH(104, 170, 26, 80));
      _drawRegion(canvas, MuscleRegion.calves, const Rect.fromLTWH(70, 276, 26, 78));
      _drawRegion(canvas, MuscleRegion.calves, const Rect.fromLTWH(104, 276, 26, 78));
    } else {
      _drawRegion(canvas, MuscleRegion.shoulders, const Rect.fromLTWH(57, 53, 86, 26));
      _drawRegion(canvas, MuscleRegion.triceps, const Rect.fromLTWH(40, 76, 21, 48));
      _drawRegion(canvas, MuscleRegion.triceps, const Rect.fromLTWH(139, 76, 21, 48));
      _drawRegion(canvas, MuscleRegion.upperBack, const Rect.fromLTWH(73, 75, 54, 45));
      _drawRegion(canvas, MuscleRegion.lowerBack, const Rect.fromLTWH(78, 120, 44, 40));
      _drawRegion(canvas, MuscleRegion.glutes, const Rect.fromLTWH(70, 166, 60, 45));
      _drawRegion(canvas, MuscleRegion.hamstrings, const Rect.fromLTWH(70, 211, 26, 64));
      _drawRegion(canvas, MuscleRegion.hamstrings, const Rect.fromLTWH(104, 211, 26, 64));
      _drawRegion(canvas, MuscleRegion.calves, const Rect.fromLTWH(70, 276, 26, 78));
      _drawRegion(canvas, MuscleRegion.calves, const Rect.fromLTWH(104, 276, 26, 78));
    }
    canvas.restore();
  }

  void _drawRegion(Canvas canvas, MuscleRegion region, Rect rect) {
    final summary = byRegion[region];
    if (summary == null || summary.level == MuscleActivityLevel.neutral) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()
        ..color = muscleLevelColor(summary.level).withValues(alpha: .82)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _MuscleBodyPainter oldDelegate) =>
      oldDelegate.isFront != isFront || oldDelegate.byRegion != byRegion;
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
