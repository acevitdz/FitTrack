import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/exercise.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import 'exercise_detail_screen.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String _muscle = 'Tất cả';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muscles = {
      'Tất cả',
      ...widget.state.templateExercises.map((item) => item.muscleGroup),
    }.toList();
    final normalized = _query.trim().toLowerCase();
    final exercises = widget.state.templateExercises.where((item) {
      final matchesQuery =
          normalized.isEmpty ||
          item.name.toLowerCase().contains(normalized) ||
          item.englishName.toLowerCase().contains(normalized);
      return matchesQuery &&
          (_muscle == 'Tất cả' || item.muscleGroup == _muscle);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Thư viện bài tập')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tìm kiếm bài tập...',
              ),
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 250), () {
                  if (mounted) setState(() => _query = value);
                });
              },
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final muscle in muscles)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(muscle),
                      selected: _muscle == muscle,
                      onSelected: (_) => setState(() => _muscle = muscle),
                    ),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Thư viện chỉ để xem. Bài tập và prescription được cung cấp sẵn theo từng chương trình.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: exercises.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off,
                    title: 'Không tìm thấy bài tập',
                    message: 'Hãy thử từ khóa hoặc nhóm cơ khác.',
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 800
                          ? 3
                          : constraints.maxWidth >= 520
                          ? 2
                          : 1;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: 268,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: exercises.length,
                        itemBuilder: (_, index) => _ExerciseCard(
                          state: widget.state,
                          exercise: exercises[index],
                          onChanged: () => setState(() {}),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.state,
    required this.exercise,
    required this.onChanged,
  });
  final AppState state;
  final Exercise exercise;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final favorite = state.favoriteExerciseIds.contains(exercise.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ExerciseDetailScreen(state: state, exercise: exercise),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
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
                            size: 54,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: IconButton.filledTonal(
                      tooltip: favorite ? 'Bỏ yêu thích' : 'Yêu thích',
                      onPressed: () {
                        state.toggleFavorite(exercise.id);
                        onChanged();
                      },
                      icon: Icon(
                        favorite ? Icons.favorite : Icons.favorite_border,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${exercise.muscleGroup} • ${exercise.difficulty} • ${exercise.equipment}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
