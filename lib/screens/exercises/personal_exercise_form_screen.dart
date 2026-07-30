import 'package:flutter/material.dart';

import '../../data/exercise_repository.dart';
import '../../models/exercise.dart';
import '../../models/exercise_enums.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/design_system.dart';

/// UI.pdf "Tạo bài tập mới" (Personal Exercise Form). Also handles edit when
/// [initial] is provided (§4 "Edit Personal Exercise" — no separate screen
/// needed, this form covers both per the doc's own suggestion).
class PersonalExerciseFormScreen extends StatefulWidget {
  const PersonalExerciseFormScreen({
    super.key,
    required this.repository,
    required this.uid,
    this.initial,
  });

  final PersonalExerciseRepository repository;
  final String uid;
  final PersonalExercise? initial;

  @override
  State<PersonalExerciseFormScreen> createState() =>
      _PersonalExerciseFormScreenState();
}

class _PersonalExerciseFormScreenState
    extends State<PersonalExerciseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _note = TextEditingController(
    text: widget.initial?.personalNote ?? '',
  );
  late final List<TextEditingController> _steps = widget.initial == null
      ? [TextEditingController()]
      : widget.initial!.instructions
            .map((text) => TextEditingController(text: text))
            .toList();

  Muscle? _primaryMuscle;
  final Set<Muscle> _secondaryMuscles = {};
  final Set<Equipment> _equipment = {};
  Difficulty _difficulty = Difficulty.beginner;
  bool _saving = false;
  bool _deleting = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _primaryMuscle = initial.primaryMuscle;
      _secondaryMuscles.addAll(initial.secondaryMuscles);
      _equipment.addAll(initial.equipment);
      _difficulty = initial.difficulty;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    for (final controller in _steps) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _deleting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_primaryMuscle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn nhóm cơ chính')),
      );
      return;
    }
    final steps = _steps
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập ít nhất 1 bước thực hiện')),
      );
      return;
    }

    setState(() => _saving = true);
    final id =
        widget.initial?.id ??
        'personal_${DateTime.now().microsecondsSinceEpoch}';
    final value = PersonalExercise(
      id: id,
      name: _name.text.trim(),
      primaryMuscle: _primaryMuscle!,
      secondaryMuscles: _secondaryMuscles.toList(),
      equipment: _equipment.toList(),
      difficulty: _difficulty,
      instructions: steps,
      personalNote: _note.text.trim(),
      isFavorite: widget.initial?.isFavorite ?? false,
    );

    if (_isEditing) {
      await widget.repository.update(widget.uid, value);
    } else {
      await widget.repository.create(widget.uid, value);
    }
    if (!mounted) return;
    Navigator.pop(context, value);
  }

  Future<void> _delete() async {
    if (_saving || _deleting) return;
    final confirmed = await confirmAction(
      context,
      title: 'Xóa bài tập cá nhân?',
      message:
          'Bài "${widget.initial!.name}" sẽ bị xóa. Lịch sử buổi tập đã lưu (nếu có) vẫn giữ nguyên.',
      confirmLabel: 'Xóa',
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    await widget.repository.delete(widget.uid, widget.initial!.id);
    if (!mounted) return;
    Navigator.pop(context, null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa bài tập' : 'Tạo bài tập mới'),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _deleting ? null : _delete,
              icon: _deleting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              tooltip: 'Xóa',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            AppFormLabel(
              label: 'Tên bài tập',
              child: TextFormField(
                controller: _name,
                decoration: const InputDecoration(hintText: 'VD: Biceps Curl...'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Vui lòng nhập tên bài tập'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            AppFormLabel(
              label: 'Nhóm cơ chính',
              child: DropdownButtonFormField<Muscle>(
                initialValue: _primaryMuscle,
                hint: const Text('Chọn nhóm cơ'),
                items: [
                  for (final muscle in Muscle.values)
                    DropdownMenuItem(value: muscle, child: Text(muscle.label)),
                ],
                onChanged: (value) => setState(() => _primaryMuscle = value),
              ),
            ),
            const SizedBox(height: 16),
            AppFormLabel(
              label: 'Nhóm cơ phụ (Không bắt buộc)',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final muscle in Muscle.values)
                    if (muscle != _primaryMuscle)
                      FilterChip(
                        label: Text(muscle.label),
                        selected: _secondaryMuscles.contains(muscle),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _secondaryMuscles.add(muscle);
                          } else {
                            _secondaryMuscles.remove(muscle);
                          }
                        }),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppFormLabel(
              label: 'Dụng cụ',
              child: Wrap(
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
            ),
            const SizedBox(height: 16),
            AppFormLabel(
              label: 'Mức độ khó',
              child: Wrap(
                spacing: 8,
                children: [
                  for (final difficulty in Difficulty.values)
                    ChoiceChip(
                      label: Text(difficulty.label),
                      selected: _difficulty == difficulty,
                      onSelected: (_) => setState(() => _difficulty = difficulty),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hướng dẫn thực hiện',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _steps.add(TextEditingController())),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm bước'),
                ),
              ],
            ),
            for (var i = 0; i < _steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(radius: 14, child: Text('${i + 1}')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _steps[i],
                        decoration: const InputDecoration(
                          hintText: 'Nhập các bước thực hiện...',
                        ),
                      ),
                    ),
                    if (_steps.length > 1)
                      IconButton(
                        onPressed: () =>
                            setState(() => _steps.removeAt(i).dispose()),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            AppFormLabel(
              label: 'Ghi chú cá nhân (Tùy chọn)',
              child: TextFormField(
                controller: _note,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Ví dụ: Lưu ý góc cổ tay khi đẩy...',
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AppPrimaryButton(
            label: 'Lưu bài tập',
            loading: _saving,
            onPressed: _save,
          ),
        ),
      ),
    );
  }
}
