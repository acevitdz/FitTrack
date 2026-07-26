import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class ExerciseFilterValue {
  const ExerciseFilterValue({
    this.difficulties = const {},
    this.equipment = const {},
    this.favoritesOnly = false,
  });

  final Set<String> difficulties;
  final Set<String> equipment;
  final bool favoritesOnly;

  int get count =>
      difficulties.length + equipment.length + (favoritesOnly ? 1 : 0);
}

Future<ExerciseFilterValue?> showExerciseFilterSheet(
  BuildContext context, {
  required ExerciseFilterValue initial,
  required Set<String> availableEquipment,
}) {
  return showModalBottomSheet<ExerciseFilterValue>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ExerciseFilterSheet(
      initial: initial,
      availableEquipment: availableEquipment,
    ),
  );
}

class _ExerciseFilterSheet extends StatefulWidget {
  const _ExerciseFilterSheet({
    required this.initial,
    required this.availableEquipment,
  });

  final ExerciseFilterValue initial;
  final Set<String> availableEquipment;

  @override
  State<_ExerciseFilterSheet> createState() => _ExerciseFilterSheetState();
}

class _ExerciseFilterSheetState extends State<_ExerciseFilterSheet> {
  late Set<String> _difficulties;
  late Set<String> _equipment;
  late bool _favoritesOnly;

  @override
  void initState() {
    super.initState();
    _difficulties = Set.of(widget.initial.difficulties);
    _equipment = Set.of(widget.initial.equipment);
    _favoritesOnly = widget.initial.favoritesOnly;
  }

  @override
  Widget build(BuildContext context) {
    final value = ExerciseFilterValue(
      difficulties: _difficulties,
      equipment: _equipment,
      favoritesOnly: _favoritesOnly,
    );
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .78,
      minChildSize: .55,
      builder: (context, controller) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Bộ lọc bài tập',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.all(18),
              children: [
                Text('Mức độ', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Cơ bản', 'Trung bình', 'Nâng cao']
                      .map(
                        (item) => FilterChip(
                          label: Text(item),
                          selected: _difficulties.contains(item),
                          onSelected: (selected) => setState(
                            () => selected
                                ? _difficulties.add(item)
                                : _difficulties.remove(item),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                Text('Dụng cụ', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.availableEquipment
                      .map(
                        (item) => FilterChip(
                          label: Text(item),
                          selected: _equipment.contains(item),
                          onSelected: (selected) => setState(
                            () => selected
                                ? _equipment.add(item)
                                : _equipment.remove(item),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Chỉ bài đã yêu thích'),
                  value: _favoritesOnly,
                  onChanged: (value) => setState(() => _favoritesOnly = value),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _difficulties.clear();
                        _equipment.clear();
                        _favoritesOnly = false;
                      }),
                      child: const Text('Đặt lại'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, value),
                      child: Text(
                        'Áp dụng${value.count > 0 ? ' (${value.count})' : ''}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
