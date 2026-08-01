import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/design_system.dart';

class FigmaBodyMetricEntryScreen extends StatefulWidget {
  const FigmaBodyMetricEntryScreen({super.key, required this.state});

  final AppState state;

  @override
  State<FigmaBodyMetricEntryScreen> createState() =>
      _FigmaBodyMetricEntryScreenState();
}

class _FigmaBodyMetricEntryScreenState
    extends State<FigmaBodyMetricEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weight;
  late final TextEditingController _note;
  late final DateTime _recordedAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _recordedAt = DateTime.now();
    _weight = TextEditingController(
      text: widget.state.profile.currentWeightKg.toStringAsFixed(1),
    );
    _note = TextEditingController();
  }

  @override
  void dispose() {
    _weight.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weightKg = _number(_weight.text);
    final heightM = widget.state.profile.heightCm / 100;
    final bmi = heightM > 0 && weightKg > 0
        ? weightKg / (heightM * heightM)
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: AppColors.outline)),
        leading: IconButton(
          tooltip: 'Đóng',
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: AppColors.text),
        ),
        centerTitle: true,
        title: const Text(
          'Nhập cân nặng',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text(
              'Lưu',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: AppPrimaryButton(
            label: 'Lưu cân nặng',
            icon: Icons.save_outlined,
            loading: _saving,
            onPressed: _save,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Column(
            children: [
              _WeightCard(
                controller: _weight,
                bmi: bmi,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: _InfoCard(
                      label: 'Ngày đo',
                      value: 'Hôm nay',
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoCard(
                      label: 'Giờ đo',
                      value: DateFormat('h:mm a').format(_recordedAt),
                      icon: Icons.access_time,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _NoteCard(controller: _note, onQuickNote: _addQuickNote),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 128,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/body_metric_scale.png',
                        fit: BoxFit.cover,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xB300408A), Color(0x0000408A)],
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 215,
                            child: Text(
                              'Theo dõi cân nặng hằng ngày để thấy sự thay đổi rõ rệt.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addQuickNote(String note) {
    final existing = _note.text.trim();
    _note.text = existing.isEmpty ? note : '$existing, $note';
    _note.selection = TextSelection.collapsed(offset: _note.text.length);
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.state.updateBodyMetrics(
        heightCm: widget.state.profile.heightCm,
        weightKg: _parse(_weight.text),
        recordedAt: _recordedAt,
        note: _note.text,
      );
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể cập nhật: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double _parse(String value) => double.parse(value.replaceAll(',', '.'));
  double _number(String value) =>
      double.tryParse(value.replaceAll(',', '.')) ?? 0;
}

class _WeightCard extends StatelessWidget {
  const _WeightCard({
    required this.controller,
    required this.bmi,
    required this.onChanged,
  });

  final TextEditingController controller;
  final double? bmi;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => _FigmaCard(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
    child: Column(
      children: [
        Text(
          'Cân nặng hiện tại (kg)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 150,
              child: TextFormField(
                key: const Key('body_metric_weight_field'),
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
                decoration: const InputDecoration(
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                ),
                onChanged: (_) => onChanged(),
                validator: (value) {
                  final kilograms =
                      double.tryParse((value ?? '').replaceAll(',', '.')) ?? 0;
                  return kilograms <= 0 || kilograms > 500
                      ? 'Cân nặng phải từ trên 0 đến 500 kg'
                      : null;
                },
              ),
            ),
            const Text(
              'kg',
              style: TextStyle(
                color: Color(0xFF737783),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (bmi != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monitor_weight_outlined,
                  size: 15,
                  color: AppColors.success,
                ),
                const SizedBox(width: 5),
                Text(
                  'BMI: ${bmi!.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Thể trạng: ${_bmiLabel(bmi!)}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF9297A3)),
          ),
        ],
      ],
    ),
  );

  String _bmiLabel(double value) {
    if (value < 18.5) return 'Thiếu cân';
    if (value < 25) return 'Bình thường';
    if (value < 30) return 'Thừa cân';
    return 'Béo phì';
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => _FigmaCard(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF737783)),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
        Icon(icon, size: 20, color: AppColors.primary),
      ],
    ),
  );
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.controller, required this.onQuickNote});

  final TextEditingController controller;
  final ValueChanged<String> onQuickNote;

  @override
  Widget build(BuildContext context) => _FigmaCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.notes_rounded, size: 19, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Ghi chú',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('body_metric_note_field'),
          controller: controller,
          minLines: 3,
          maxLines: 4,
          maxLength: 200,
          decoration: const InputDecoration(
            hintText: 'VD: Vừa ngủ dậy, Sau khi tập gym...',
            counterText: '',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final note in const [
              'Vừa ngủ dậy',
              'Sau khi tập',
              'Trước bữa tối',
            ])
              _QuickNoteChip(note: note, onTap: () => onQuickNote(note)),
          ],
        ),
      ],
    ),
  );
}

class _QuickNoteChip extends StatelessWidget {
  const _QuickNoteChip({required this.note, required this.onTap});

  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    key: Key('body_metric_quick_note_$note'),
    label: Text(note),
    onPressed: onTap,
    side: const BorderSide(color: AppColors.outline),
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    labelStyle: const TextStyle(
      color: AppColors.textMuted,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
  );
}

class _FigmaCard extends StatelessWidget {
  const _FigmaCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.outline),
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}
