import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/health_models.dart';
import '../../models/measurement_units.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/design_system.dart';

import 'figma_body_metric_entry_screen.dart';

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key, required this.state});

  final AppState state;

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  var _periodDays = 7;

  Future<void> _updateMetrics() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FigmaBodyMetricEntryScreen(state: widget.state),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final entries = [...widget.state.weightEntries]
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final cutoff = DateTime.now().subtract(Duration(days: _periodDays));
    final chartEntries = entries
        .where((item) => !item.recordedAt.isBefore(cutoff))
        .toList();
    final bmi = widget.state.profile.bmi;
    final unit = MeasurementUnitSystem.fromStored(widget.state.unit);
    final periodChange = chartEntries.length < 2
        ? 0.0
        : unit.weightFromKilograms(
            chartEntries.last.weightKg - chartEntries.first.weightKg,
          );
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉ số cơ thể'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nhập cân nặng',
        onPressed: _updateMetrics,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'BMI hiện tại',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Chip(label: Text(_bmiLabel(bmi))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    bmi.isFinite ? bmi.toStringAsFixed(1) : 'Chưa đủ dữ liệu',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _BmiRangeIndicator(value: bmi),
                  Text(
                    '${unit.formatHeight(widget.state.profile.heightCm)} • '
                    '${unit.formatWeight(widget.state.profile.currentWeightKg)}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.input,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'BMI chỉ mang tính tham khảo và không thay thế tư vấn y khoa.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tiến độ cân nặng',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 7, label: Text('Tuần')),
                          ButtonSegment(value: 30, label: Text('Tháng')),
                        ],
                        selected: {_periodDays},
                        onSelectionChanged: (value) =>
                            setState(() => _periodDays = value.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: chartEntries.length < 2
                        ? const EmptyState(
                            icon: Icons.show_chart,
                            title: 'Chưa đủ dữ liệu',
                            message: 'Cần ít nhất hai lần đo trong kỳ đã chọn.',
                          )
                        : _BodyMetricChart(entries: chartEntries, unit: unit),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _ProgressValue(
                          label: 'Hiện tại',
                          value: unit.formatWeight(
                            widget.state.profile.currentWeightKg,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _ProgressValue(
                          label: 'Thay đổi',
                          value:
                              '${periodChange > 0 ? '+' : ''}${periodChange.toStringAsFixed(1)} ${unit.weightSymbol}',
                          valueColor: periodChange <= 0
                              ? AppColors.success
                              : AppColors.error,
                          alignEnd: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Lịch sử đo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            EmptyState(
              icon: Icons.monitor_weight_outlined,
              title: 'Chưa có dữ liệu',
              message: 'Cập nhật chiều cao và cân nặng để bắt đầu theo dõi.',
              action: FilledButton(
                onPressed: _updateMetrics,
                child: const Text('Cập nhật chỉ số'),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var index = entries.length - 1; index >= 0; index--) ...[
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.input,
                        child: Icon(Icons.straighten),
                      ),
                      title: Text(unit.formatWeight(entries[index].weightKg)),
                      subtitle: Text(
                        '${entries[index].heightCm == null ? '—' : unit.formatHeight(entries[index].heightCm!)} • '
                        'BMI ${entries[index].bmi?.toStringAsFixed(1) ?? '—'} • '
                        '${DateFormat('dd/MM/yyyy • HH:mm').format(entries[index].recordedAt)}',
                      ),
                    ),
                    if (index > 0) const Divider(height: 1),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _bmiLabel(double value) {
    if (!value.isFinite || value <= 0) return 'Chưa đủ dữ liệu';
    if (value < 18.5) return 'Thấp';
    if (value < 25) return 'Cân đối';
    if (value < 30) return 'Cao';
    return 'Thừa cân';
  }
}

class _BmiRangeIndicator extends StatelessWidget {
  const _BmiRangeIndicator({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final ratio = value.isFinite
        ? ((value - 15) / 25).clamp(0.0, 1.0).toDouble()
        : 0.0;
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: 30,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ColoredBox(
                        color: AppColors.primary,
                        child: SizedBox(height: 9),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: ColoredBox(
                        color: AppColors.success,
                        child: SizedBox(height: 9),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: ColoredBox(
                        color: AppColors.warning,
                        child: SizedBox(height: 9),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: ColoredBox(
                        color: AppColors.error,
                        child: SizedBox(height: 9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 7,
              left: ratio * (constraints.maxWidth - 20),
              child: const Icon(
                Icons.arrow_drop_up,
                color: AppColors.text,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressValue extends StatelessWidget {
  const _ProgressValue({
    required this.label,
    required this.value,
    this.valueColor,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: valueColor ?? AppColors.text,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class BodyMetricEntryScreen extends StatefulWidget {
  const BodyMetricEntryScreen({super.key, required this.state});
  final AppState state;

  @override
  State<BodyMetricEntryScreen> createState() => _BodyMetricEntryScreenState();
}

class _BodyMetricEntryScreenState extends State<BodyMetricEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late MeasurementUnitSystem _unit;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _unit = MeasurementUnitSystem.fromStored(widget.state.unit);
    _height = TextEditingController(
      text: _unit
          .heightFromCentimeters(widget.state.profile.heightCm)
          .toStringAsFixed(_unit == MeasurementUnitSystem.metric ? 0 : 1),
    );
    _weight = TextEditingController(
      text: _unit
          .weightFromKilograms(widget.state.profile.currentWeightKg)
          .toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final heightCm = _unit.heightToCentimeters(_parse(_height.text));
      final weightKg = _unit.weightToKilograms(_parse(_weight.text));
      await widget.state.updateBodyMetrics(
        heightCm: heightCm,
        weightKg: weightKg,
      );
      await widget.state.setUnit(_unit.storageKey);
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

  @override
  Widget build(BuildContext context) {
    final heightCm = _unit.heightToCentimeters(_parseOrZero(_height.text));
    final weightKg = _unit.weightToKilograms(_parseOrZero(_weight.text));
    final meters = heightCm / 100;
    final bmi = meters > 0 && weightKg > 0
        ? weightKg / (meters * meters)
        : null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Đóng',
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: const Text('Nhập cân nặng'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Lưu'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: FitTrackPage(
          maxWidth: 390,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cập nhật chỉ số hôm nay',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Nhập chiều cao và cân nặng để FitTrack tự động tính BMI và theo dõi tiến độ.',
              ),
              const SizedBox(height: 16),
              SegmentedButton<MeasurementUnitSystem>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: MeasurementUnitSystem.metric,
                    label: Text('cm / kg'),
                  ),
                  ButtonSegment(
                    value: MeasurementUnitSystem.imperial,
                    label: Text('in / lb'),
                  ),
                ],
                selected: {_unit},
                onSelectionChanged: (values) => _changeUnit(values.first),
              ),
              const SizedBox(height: 24),
              AppFormLabel(
                label: 'Chiều cao (${_unit.heightSymbol})',
                child: TextFormField(
                  controller: _height,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(suffixText: _unit.heightSymbol),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    final number = _parseOrZero(value ?? '');
                    final centimeters = _unit.heightToCentimeters(number);
                    return centimeters < 100 || centimeters > 250
                        ? 'Nhập chiều cao tương đương 100–250 cm'
                        : null;
                  },
                ),
              ),
              const SizedBox(height: 18),
              AppFormLabel(
                label: 'Cân nặng (${_unit.weightSymbol})',
                child: TextFormField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(suffixText: _unit.weightSymbol),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    final number = _parseOrZero(value ?? '');
                    final kilograms = _unit.weightToKilograms(number);
                    return kilograms <= 0 || kilograms > 500
                        ? 'Nhập cân nặng tương đương trên 0 và không quá 500 kg'
                        : null;
                  },
                ),
              ),
              const SizedBox(height: 22),
              Card(
                color: AppColors.paleBlue.withValues(alpha: .45),
                child: ListTile(
                  leading: const Icon(Icons.calculate_outlined),
                  title: const Text('BMI tự tính'),
                  trailing: Text(
                    bmi?.toStringAsFixed(1) ?? 'Chưa đủ dữ liệu',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              AppPrimaryButton(
                label: 'Lưu chỉ số',
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _parse(String value) => double.parse(value.replaceAll(',', '.'));
  double _parseOrZero(String value) =>
      double.tryParse(value.replaceAll(',', '.')) ?? 0;

  void _changeUnit(MeasurementUnitSystem next) {
    if (next == _unit) return;
    final height = _parseOrZero(_height.text);
    final weight = _parseOrZero(_weight.text);
    final heightCm = _unit.heightToCentimeters(height);
    final weightKg = _unit.weightToKilograms(weight);
    setState(() {
      _unit = next;
      if (height > 0) {
        _height.text = next
            .heightFromCentimeters(heightCm)
            .toStringAsFixed(next == MeasurementUnitSystem.metric ? 0 : 1);
      }
      if (weight > 0) {
        _weight.text = next.weightFromKilograms(weightKg).toStringAsFixed(1);
      }
    });
  }
}

class _BodyMetricChart extends StatelessWidget {
  const _BodyMetricChart({required this.entries, required this.unit});
  final List<WeightEntry> entries;
  final MeasurementUnitSystem unit;

  @override
  Widget build(BuildContext context) => LineChart(
    LineChartData(
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(drawVerticalLine: false),
      titlesData: const FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: entries.indexed
              .map(
                (item) => FlSpot(
                  item.$1.toDouble(),
                  unit.weightFromKilograms(item.$2.weightKg),
                ),
              )
              .toList(),
          color: AppColors.primary,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.paleBlue.withValues(alpha: .35),
          ),
        ),
      ],
    ),
  );
}
