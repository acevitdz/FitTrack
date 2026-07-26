import 'package:flutter/material.dart';

import '../../models/exercise.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';

class ExerciseDetailScreen extends StatefulWidget {
  const ExerciseDetailScreen({
    super.key,
    required this.state,
    required this.exercise,
  });
  final AppState state;
  final Exercise exercise;

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final favorite = widget.state.favoriteExerciseIds.contains(exercise.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name),
        actions: [
          IconButton(
            tooltip: favorite ? 'Bỏ yêu thích' : 'Yêu thích',
            onPressed: () {
              widget.state.toggleFavorite(exercise.id);
              setState(() {});
            },
            icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [AppColors.navySurface, AppColors.action],
              ),
              image: fitTrackImageProvider(exercise.imageUrl) == null
                  ? null
                  : DecorationImage(
                      image: fitTrackImageProvider(exercise.imageUrl)!,
                      fit: BoxFit.cover,
                    ),
            ),
            child: exercise.imageUrl == null
                ? const Icon(
                    Icons.fitness_center,
                    size: 72,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(height: 18),
          Text(exercise.name, style: Theme.of(context).textTheme.headlineSmall),
          if (exercise.englishName.isNotEmpty)
            Text(
              exercise.englishName,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(exercise.muscleGroup)),
              Chip(label: Text(exercise.difficulty)),
              Chip(label: Text(exercise.equipment)),
            ],
          ),
          if (exercise.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(exercise.description),
          ],
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
