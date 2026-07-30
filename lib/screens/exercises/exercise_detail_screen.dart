import 'package:flutter/material.dart';

import '../../models/exercise.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';

/// UI.pdf "Chi tiết bài tập" (Exercise Detail).
class ExerciseDetailScreen extends StatefulWidget {
  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
    required this.favorite,
    required this.onToggleFavorite,
  });

  final Exercise exercise;
  final bool favorite;
  final VoidCallback onToggleFavorite;

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  late bool _favorite = widget.favorite;

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name),
        actions: [
          IconButton(
            tooltip: _favorite ? 'Bỏ yêu thích' : 'Yêu thích',
            onPressed: () {
              widget.onToggleFavorite();
              setState(() => _favorite = !_favorite);
            },
            icon: Icon(
              _favorite ? Icons.favorite : Icons.favorite_border,
              color: _favorite ? AppColors.error : null,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image(
              image: fitTrackImageProvider(exercise.imageUrl)!,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 18),
          Text(exercise.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(exercise.primaryMuscle.label)),
              for (final muscle in exercise.secondaryMuscles)
                Chip(label: Text(muscle.label)),
              Chip(label: Text(exercise.difficulty.label)),
              for (final equipment in exercise.equipment)
                Chip(label: Text(equipment.label)),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.paleBlue.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(exercise.quickTip)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 18, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                'Nghỉ gợi ý: ${exercise.suggestedRestSeconds}s giữa các hiệp',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text('Cách thực hiện', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (var index = 0; index < exercise.instructions.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(exercise.instructions[index]),
            ),
          if (exercise.commonMistakes.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Lỗi thường gặp',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            for (final mistake in exercise.commonMistakes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.warning_amber,
                  color: AppColors.warning,
                ),
                title: Text(mistake),
              ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Prescription (số hiệp, mục tiêu và lịch) chỉ xuất hiện trong chương trình đã phát hành. Người dùng không thêm bài này vào kế hoạch thủ công.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
