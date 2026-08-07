import 'package:flutter/material.dart';

import '../../services/workout_insights.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import 'muscle_body_diagram_svg.dart';
import 'muscle_detail_screen.dart';

enum _MuscleWindow { week, month }

class MuscleBalanceScreen extends StatefulWidget {
  const MuscleBalanceScreen({super.key, required this.state});

  final AppState state;

  @override
  State<MuscleBalanceScreen> createState() => _MuscleBalanceScreenState();
}

class _MuscleBalanceScreenState extends State<MuscleBalanceScreen> {
  var _window = _MuscleWindow.week;
  var _includeSecondary = true;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = _window == _MuscleWindow.week ? 7 : 30;
    final result = computeMuscleBalance(
      completions: widget.state.completedTargetWorkouts,
      windowStart: now.subtract(Duration(days: days)),
      now: now,
      includeSecondary: _includeSecondary,
    );
    final regions = MuscleRegion.values.toList()
      ..sort((left, right) {
        final leftSummary = result.byRegion[left]!;
        final rightSummary = result.byRegion[right]!;
        final change = rightSummary.changeFromBaseline.abs().compareTo(
          leftSummary.changeFromBaseline.abs(),
        );
        if (change != 0) return change;
        return rightSummary.weightedSets.compareTo(leftSummary.weightedSets);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Bản đồ cân bằng cơ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text(
            'Phân tích theo số hiệp đã hoàn thành trong lộ trình tự động. Không sử dụng tạ hoặc volume.',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          SegmentedButton<_MuscleWindow>(
            segments: const [
              ButtonSegment(value: _MuscleWindow.week, label: Text('7 ngày')),
              ButtonSegment(value: _MuscleWindow.month, label: Text('30 ngày')),
            ],
            selected: {_window},
            onSelectionChanged: (value) =>
                setState(() => _window = value.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Tính cả nhóm cơ phụ (0,5 hiệp)'),
            value: _includeSecondary,
            onChanged: (value) => setState(() => _includeSecondary = value),
          ),
          const SizedBox(height: 8),
          _BalanceBanner(
            summary: result.highestRegion == null
                ? null
                : result.byRegion[result.highestRegion],
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 250,
              child: MuscleBodyDiagram(
                byRegion: result.byRegion,
                onTapRegion: (region) => _openDetail(context, result, region),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: MuscleDiagramLegend()),
          const SizedBox(height: 22),
          Text(
            'Chi tiết theo nhóm cơ',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              for (final region in regions)
                _MuscleCard(
                  summary: result.byRegion[region]!,
                  onTap: () => _openDetail(context, result, region),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openDetail(
    BuildContext context,
    MuscleBalanceResult result,
    MuscleRegion region,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MuscleDetailScreen(
          state: widget.state,
          summary: result.byRegion[region]!,
        ),
      ),
    );
  }
}

class _BalanceBanner extends StatelessWidget {
  const _BalanceBanner({required this.summary});

  final MuscleActivitySummary? summary;

  @override
  Widget build(BuildContext context) {
    if (summary == null) {
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
            Expanded(child: Text('Chưa phát hiện nhóm cơ có mức tăng bất thường.')),
          ],
        ),
      );
    }
    final percent = (summary!.changeFromBaseline * 100).round();
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
            child: Text(
              'Nhóm cơ ${summary!.region.label} cao hơn khoảng $percent% so với mức hiệp thông thường gần đây của chính bạn.',
            ),
          ),
        ],
      ),
    );
  }
}

class _MuscleCard extends StatelessWidget {
  const _MuscleCard({required this.summary, required this.onTap});

  final MuscleActivitySummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (summary.level) {
      MuscleActivityLevel.neutral => ('Chưa có dữ liệu', AppColors.textMuted),
      MuscleActivityLevel.low => ('Thấp', AppColors.accent),
      MuscleActivityLevel.medium => ('Trung bình', AppColors.success),
      MuscleActivityLevel.high => ('Cao', AppColors.warning),
    };
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary.region.label.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                '${_formatSets(summary.weightedSets)} hiệp · ${summary.sessions.length} buổi',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSets(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
}
