import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/exercise_repository.dart';
import '../../models/exercise.dart';
import '../../models/exercise_enums.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import 'exercise_detail_screen.dart';
import 'exercise_filter_sheet.dart';

/// UI.pdf "Thư viện bài tập" (Exercise Library) — SRS §4.4: xem, tìm kiếm,
/// lọc theo nhóm cơ, đánh dấu yêu thích.
class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({
    super.key,
    required this.exerciseRepository,
    required this.favoriteRepository,
    required this.uid,
  });

  final ExerciseRepository exerciseRepository;
  final FavoriteExerciseRepository favoriteRepository;
  final String uid;

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  List<Exercise>? _all;
  Set<String> _favoriteIds = {};
  ExerciseFilter _filter = const ExerciseFilter();
  StreamSubscription<List<Exercise>>? _exerciseSub;
  StreamSubscription<Set<String>>? _favoriteSub;

  @override
  void initState() {
    super.initState();
    _exerciseSub = widget.exerciseRepository.watchExercises().listen((value) {
      setState(() => _all = value);
    });
    _favoriteSub = widget.favoriteRepository.watchFavoriteIds(widget.uid).listen((
      value,
    ) {
      setState(() => _favoriteIds = value);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _exerciseSub?.cancel();
    _favoriteSub?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _openFilterSheet() async {
    final all = _all ?? const [];
    // Refresh the filter's favoriteIds snapshot (if it was already active)
    // so reopening the sheet reflects any favoriting done since the last
    // apply — the sheet itself always uses currentFavoriteIds for the
    // switch's own on/off value, see exercise_filter_sheet.dart.
    final currentFilter = _filter.favoriteIds != null
        ? _filter.copyWith(favoriteIds: _favoriteIds)
        : _filter;
    final result = await showExerciseFilterSheet(
      context,
      initial: currentFilter,
      allExercises: all,
      currentFavoriteIds: _favoriteIds,
    );
    if (result != null) setState(() => _filter = result);
  }

  void _toggleFavorite(String exerciseId) {
    final isFavorite = _favoriteIds.contains(exerciseId);
    widget.favoriteRepository.setFavorite(
      widget.uid,
      exerciseId,
      !isFavorite,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = _all == null;
    final visible = loading
        ? const <Exercise>[]
        : _all!.where(_filter.matches).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Thư viện bài tập')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Tìm kiếm bài tập...',
                    ),
                    onChanged: (value) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 250), () {
                        if (mounted) {
                          setState(() => _filter = _filter.copyWith(query: value));
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: _filter.activeCount > 0,
                  label: Text('${_filter.activeCount}'),
                  child: IconButton.filledTonal(
                    onPressed: _openFilterSheet,
                    icon: const Icon(Icons.tune),
                    tooltip: 'Bộ lọc',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Tất cả'),
                    selected: _filter.muscle == null,
                    onSelected: (_) =>
                        setState(() => _filter = _filter.copyWith(clearMuscle: true)),
                  ),
                ),
                for (final muscle in Muscle.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(muscle.label),
                      selected: _filter.muscle == muscle,
                      onSelected: (_) =>
                          setState(() => _filter = _filter.copyWith(muscle: muscle)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                ? EmptyState(
                    icon: Icons.search_off,
                    title: 'Không tìm thấy bài tập',
                    message: 'Thử đổi từ khóa tìm kiếm hoặc bộ lọc khác.',
                    action: TextButton(
                      onPressed: () => setState(() {
                        _search.clear();
                        _filter = const ExerciseFilter();
                      }),
                      child: const Text('Xóa bộ lọc'),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final exercise = visible[index];
                      return _ExerciseCard(
                        exercise: exercise,
                        favorite: _favoriteIds.contains(exercise.id),
                        onToggleFavorite: () => _toggleFavorite(exercise.id),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExerciseDetailScreen(
                              exercise: exercise,
                              favorite: _favoriteIds.contains(exercise.id),
                              onToggleFavorite: () =>
                                  _toggleFavorite(exercise.id),
                            ),
                          ),
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
    required this.exercise,
    required this.favorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final Exercise exercise;
  final bool favorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image(
                  image: fitTrackImageProvider(exercise.imageUrl)!,
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            exercise.name,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: onToggleFavorite,
                          icon: Icon(
                            favorite ? Icons.favorite : Icons.favorite_border,
                            color: favorite ? AppColors.error : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(exercise.primaryMuscle.label),
                          padding: EdgeInsets.zero,
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(exercise.difficulty.label),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
