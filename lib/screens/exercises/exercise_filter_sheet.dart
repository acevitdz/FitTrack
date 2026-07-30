import 'package:flutter/material.dart';

import '../../data/exercise_repository.dart';
import '../../models/exercise.dart';
import '../../models/exercise_enums.dart';
import '../../theme/app_colors.dart';

/// UI.pdf "Bộ lọc" (Filter Bottom Sheet). Returns the edited [ExerciseFilter]
/// on "Áp dụng", or null if dismissed without applying.
Future<ExerciseFilter?> showExerciseFilterSheet(
  BuildContext context, {
  required ExerciseFilter initial,
  required List<Exercise> allExercises,
  required Set<String> currentFavoriteIds,
}) {
  return showModalBottomSheet<ExerciseFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ExerciseFilterSheet(
      initial: initial,
      allExercises: allExercises,
      currentFavoriteIds: currentFavoriteIds,
    ),
  );
}

class _ExerciseFilterSheet extends StatefulWidget {
  const _ExerciseFilterSheet({
    required this.initial,
    required this.allExercises,
    required this.currentFavoriteIds,
  });

  final ExerciseFilter initial;
  final List<Exercise> allExercises;

  /// The user's actual current favorite ids (from FavoriteExerciseRepository),
  /// used when the "chỉ hiện thị yêu thích" switch is on — NOT
  /// `initial.favoriteIds`, which is only a snapshot from the last time this
  /// filter was applied and is null the very first time the switch is used.
  final Set<String> currentFavoriteIds;

  @override
  State<_ExerciseFilterSheet> createState() => _ExerciseFilterSheetState();
}

class _ExerciseFilterSheetState extends State<_ExerciseFilterSheet> {
  late Muscle? _muscle = widget.initial.muscle;
  late Set<Difficulty> _difficulties = {...widget.initial.difficulties};
  late Set<Equipment> _equipment = {...widget.initial.equipment};
  late bool _favoritesOnly = widget.initial.favoriteIds != null;

  int get _liveCount {
    final draft = widget.initial.copyWith(
      muscle: _muscle,
      clearMuscle: _muscle == null,
      difficulties: _difficulties,
      equipment: _equipment,
      favoriteIds: _favoritesOnly ? widget.currentFavoriteIds : null,
      clearFavoriteIds: !_favoritesOnly,
    );
    return widget.allExercises.where(draft.matches).length;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Bộ lọc', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _sectionLabel('NHÓM CƠ'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Tất cả'),
                          selected: _muscle == null,
                          onSelected: (_) => setState(() => _muscle = null),
                        ),
                        for (final muscle in Muscle.values)
                          ChoiceChip(
                            label: Text(muscle.label),
                            selected: _muscle == muscle,
                            onSelected: (_) =>
                                setState(() => _muscle = muscle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('ĐỘ KHÓ'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final difficulty in Difficulty.values)
                          FilterChip(
                            label: Text(difficulty.label),
                            selected: _difficulties.contains(difficulty),
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _difficulties.add(difficulty);
                              } else {
                                _difficulties.remove(difficulty);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('DỤNG CỤ'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final equipment in Equipment.values)
                          FilterChip(
                            label: Text(equipment.label),
                            selected: _equipment.contains(equipment),
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _equipment.add(equipment);
                              } else {
                                _equipment.remove(equipment);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Chỉ hiện thị mức yêu thích'),
                      value: _favoritesOnly,
                      onChanged: (value) =>
                          setState(() => _favoritesOnly = value),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _muscle = null;
                        _difficulties = {};
                        _equipment = {};
                        _favoritesOnly = false;
                      }),
                      child: const Text('Xóa bộ lọc'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                        context,
                        widget.initial.copyWith(
                          muscle: _muscle,
                          clearMuscle: _muscle == null,
                          difficulties: _difficulties,
                          equipment: _equipment,
                          favoriteIds: _favoritesOnly
                              ? widget.currentFavoriteIds
                              : null,
                          clearFavoriteIds: !_favoritesOnly,
                        ),
                      ),
                      child: Text('Áp dụng ($_liveCount)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: .5,
      ),
    ),
  );
}
