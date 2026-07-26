import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/health_models.dart';
import '../../models/measurement_units.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/design_system.dart';

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
        builder: (_) => BodyMetricEntryScreen(state: widget.state),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉ số cơ thể'),
        actions: [
          TextButton(onPressed: _updateMetrics, child: const Text('Cập nhật')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Chiều cao',
                  value: unit.formatHeight(widget.state.profile.heightCm),
                  icon: Icons.height,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricCard(
                  label: 'Cân nặng',
                  value: unit.formatWeight(
                    widget.state.profile.currentWeightKg,
                  ),
                  icon: Icons.monitor_weight_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Streak',
                  value: '${widget.state.currentStreak} ngày',
                  icon: Icons.local_fire_department_outlined,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricCard(
                  label: 'Chuỗi kỷ lục',
                  value: '${widget.state.longestStreak} ngày',
                  icon: Icons.workspace_premium_outlined,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Nhập cân nặng trong ngày để duy trì streak hằng ngày. Nhiều lần cập nhật trong cùng một ngày vẫn chỉ được tính một ngày.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
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
                        'BMI tham khảo',
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
                  const Text(
                    'BMI chỉ là chỉ số sàng lọc tham khảo, không phản ánh đầy đủ thành phần cơ thể và không được FitTrack dùng một mình để thay đổi bài tập.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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
                          'Biểu đồ cân nặng',
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
                    height: 280,
                    child: chartEntries.length < 2
                        ? const EmptyState(
                            icon: Icons.show_chart,
                            title: 'Chưa đủ dữ liệu',
                            message: 'Cần ít nhất hai lần đo trong kỳ đã chọn.',
                          )
                        : _BodyMetricChart(
                            entries: chartEntries,
                            unit: unit,
                          ),
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
                      title: Text(
                        unit.formatWeight(entries[index].weightKg),
                      ),
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
    final heightCm = _unit.heightToCentimeters(
      _parseOrZero(_height.text),
    );
    final weightKg = _unit.weightToKilograms(
      _parseOrZero(_weight.text),
    );
    final meters = heightCm / 100;
    final bmi = meters > 0 && weightKg > 0
        ? weightKg / (meters * meters)
        : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cập nhật chỉ số'),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hai số liệu sức khỏe duy nhất',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'FitTrack chỉ yêu cầu chiều cao và cân nặng. BMI được tính tự động; lưu cân nặng sẽ duy trì streak hằng ngày, tối đa một lần tính mỗi ngày.',
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
