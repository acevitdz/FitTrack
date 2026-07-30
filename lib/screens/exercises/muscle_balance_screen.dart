import 'package:flutter/material.dart';

import '../../data/exercise_repository.dart';
import '../../domain/muscle_balance_calculator.dart';
import '../../models/exercise.dart';
import '../../models/exercise_enums.dart';
import '../../models/exercise_set_log.dart';
import '../../theme/app_colors.dart';
import 'muscle_body_diagram.dart';
import 'muscle_detail_screen.dart';

enum _Window { week, month }

/// UI.pdf "Bản đồ cân bằng cơ" (Muscle Balance) — SRS §4.12.
/// [logs] stands in for TV3's WorkoutCompletion feed — see
/// lib/models/exercise_set_log.dart.
class MuscleBalanceScreen extends StatefulWidget {
  const MuscleBalanceScreen({
    super.key,
    required this.exercises,
    required this.logs,
    required this.favoriteRepository,
    required this.uid,
  });

  final List<Exercise> exercises;
  final List<ExerciseSetLog> logs;
  final FavoriteExerciseRepository favoriteRepository;
  final String uid;

  @override
  State<MuscleBalanceScreen> createState() => _MuscleBalanceScreenState();
}

class _MuscleBalanceScreenState extends State<MuscleBalanceScreen> {
  var _window = _Window.week;
  var _includeSecondary = true;

  @override
  Widget build(BuildContext context) {
    final exercisesById = {for (final e in widget.exercises) e.id: e};
    final windowStart = DateTime.now().subtract(
      Duration(days: _window == _Window.week ? 7 : 30),
    );
    final result = computeMuscleBalance(
      logs: widget.logs,
      exercisesById: exercisesById,
      windowStart: windowStart,
      includeSecondary: _includeSecondary,
    );
    final sortedMuscles = Muscle.values.toList()
      ..sort(
        (a, b) => result.byMuscle[b]!.changeFromBaseline
            .abs()
            .compareTo(result.byMuscle[a]!.changeFromBaseline.abs()),
      );

    return Scaffold(
      appBar: AppBar(title: const Text('Bản đồ cân bằng cơ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Phân tích mức độ tập luyện các nhóm cơ trong '
                  '${_window == _Window.week ? "7 ngày" : "30 ngày"} qua.',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<_Window>(
            segments: const [
              ButtonSegment(value: _Window.week, label: Text('Tuần')),
              ButtonSegment(value: _Window.month, label: Text('Tháng')),
            ],
            selected: {_window},
            onSelectionChanged: (value) =>
                setState(() => _window = value.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Tính cả nhóm cơ phụ (trọng số 0.5)'),
            value: _includeSecondary,
            onChanged: (value) => setState(() => _includeSecondary = value),
          ),
          const SizedBox(height: 10),
          if (result.overtrained != null)
            _ImbalanceBanner(summary: result.byMuscle[result.overtrained]!)
          else
            const _NeutralBanner(),
          const SizedBox(height: 22),
          Center(
            child: SizedBox(
              width: 260,
              child: MuscleBodyDiagram(
                byMuscle: result.byMuscle,
                onTapMuscle: (muscle) => _openMuscle(context, result, muscle),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(child: BodyDiagramLegend()),
          const SizedBox(height: 22),
          Text(
            'Chi tiết theo nhóm cơ (lệch nhiều nhất trước)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              for (final muscle in sortedMuscles)
                _MuscleCard(
                  summary: result.byMuscle[muscle]!,
                  onTap: () => _openMuscle(context, result, muscle),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openMuscle(BuildContext context, MuscleBalanceResult result, Muscle muscle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MuscleDetailScreen(
          summary: result.byMuscle[muscle]!,
          exercises: widget.exercises,
          favoriteRepository: widget.favoriteRepository,
          uid: widget.uid,
        ),
      ),
    );
  }
}

class _ImbalanceBanner extends StatelessWidget {
  const _ImbalanceBanner({required this.summary});
  final MuscleVolumeSummary summary;

  @override
  Widget build(BuildContext context) {
    final percent = (summary.changeFromBaseline * 100).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: .4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mất cân bằng nhẹ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nhóm cơ ${summary.muscle.label} đang cao hơn khoảng $percent% so '
                  'với mức bình thường gần đây của chính bạn. Hãy tập trung vào các '
                  'nhóm cơ đối trọng trong buổi tập tới.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NeutralBanner extends StatelessWidget {
  const _NeutralBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.success),
          SizedBox(width: 10),
          Expanded(
            child: Text('Chưa phát hiện mất cân bằng rõ rệt trong giai đoạn này.'),
          ),
        ],
      ),
    );
  }
}

class _MuscleCard extends StatelessWidget {
  const _MuscleCard({required this.summary, required this.onTap});

  final MuscleVolumeSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (summary.level) {
      MuscleVolumeLevel.neutral => ('Chưa có dữ liệu', AppColors.textMuted),
      MuscleVolumeLevel.low => ('Thấp', AppColors.accent),
      MuscleVolumeLevel.medium => ('Trung bình', AppColors.success),
      MuscleVolumeLevel.high => ('Cao', AppColors.warning),
    };
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary.muscle.label.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                summary.lastTrained == null
                    ? 'Chưa tập'
                    : 'Lần cuối: ${_relativeDate(summary.lastTrained!)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeDate(DateTime date) {
    final days = DateTime.now().difference(date).inDays;
    if (days <= 0) return 'Hôm nay';
    if (days == 1) return 'Hôm qua';
    return '$days ngày trước';
  }
}
