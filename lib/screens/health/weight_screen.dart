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
    final cutoff = _periodDays == 0
        ? null
        : DateTime.now().subtract(Duration(days: _periodDays));
    final chartEntries = _latestEntryPerDay(
      entries.where(
        (item) => cutoff == null || !item.recordedAt.isBefore(cutoff),
      ),
    );
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
                  label: 'Chuỗi ngày hiện tại',
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
            'Nhập cân nặng trong ngày để duy trì chuỗi hoạt động. Nhiều lần cập nhật trong cùng một ngày vẫn chỉ được tính một ngày.',
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
                      PopupMenuButton<int>(
                        initialValue: _periodDays,
                        tooltip: 'Chọn khoảng thời gian',
                        onSelected: (value) =>
                            setState(() => _periodDays = value),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 7, child: Text('7 ngày')),
                          PopupMenuItem(value: 30, child: Text('30 ngày')),
                          PopupMenuItem(value: 90, child: Text('90 ngày')),
                          PopupMenuItem(value: 0, child: Text('Toàn bộ')),
                        ],
                        child: Chip(
                          avatar: const Icon(Icons.date_range_outlined),
                          label: Text(
                            _periodDays == 0 ? 'Toàn bộ' : '$_periodDays ngày',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (chartEntries.length >= 2) ...[
                    const SizedBox(height: 10),
                    _TrendSummary(entries: chartEntries, unit: unit),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 280,
                    child: chartEntries.length < 2
                        ? const EmptyState(
                            icon: Icons.show_chart,
                            title: 'Chưa đủ dữ liệu',
                            message:
                                'Cần ít nhất hai ngày có dữ liệu trong kỳ đã chọn.',
                          )
                        : _BodyMetricChart(entries: chartEntries, unit: unit),
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

  List<WeightEntry> _latestEntryPerDay(Iterable<WeightEntry> source) {
    final latest = <DateTime, WeightEntry>{};
    for (final entry in source) {
      final day = DateTime(
        entry.recordedAt.year,
        entry.recordedAt.month,
        entry.recordedAt.day,
      );
      final current = latest[day];
      if (current == null || entry.recordedAt.isAfter(current.recordedAt)) {
        latest[day] = entry;
      }
    }
    return latest.values.toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
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
  late DateTime _recordedAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _recordedAt = DateTime.now();
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
        recordedAt: _recordedAt,
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
                'FitTrack chỉ yêu cầu chiều cao và cân nặng. BMI được tính tự động; lưu cân nặng sẽ duy trì chuỗi hoạt động, tối đa một lần tính mỗi ngày.',
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
                label: 'Thời điểm đo',
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.event_outlined),
                    title: Text(
                      DateFormat('dd/MM/yyyy • HH:mm').format(_recordedAt),
                    ),
                    subtitle: const Text(
                      'Dùng thời điểm thực tế để biểu đồ và lịch sử chính xác.',
                    ),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: _pickRecordedAt,
                  ),
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

  Future<void> _pickRecordedAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _recordedAt.isAfter(now) ? now : _recordedAt,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Chọn ngày đo',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_recordedAt),
      helpText: 'Chọn giờ đo',
    );
    if (time == null) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() => _recordedAt = selected.isAfter(now) ? now : selected);
  }

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

  double _day(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day).millisecondsSinceEpoch /
      Duration.millisecondsPerDay;

  @override
  Widget build(BuildContext context) {
    final spots = entries
        .map(
          (entry) => FlSpot(
            _day(entry.recordedAt),
            unit.weightFromKilograms(entry.weightKg),
          ),
        )
        .toList();
    final weights = spots.map((spot) => spot.y);
    final low = weights.reduce((a, b) => a < b ? a : b);
    final high = weights.reduce((a, b) => a > b ? a : b);
    final padding = (high - low).abs() < .5 ? 1.0 : (high - low) * .2;
    return LineChart(
      LineChartData(
        minX: spots.first.x,
        maxX: spots.last.x,
        minY: low - padding,
        maxY: high + padding,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(drawVerticalLine: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (spots.last.x - spots.first.x).clamp(1, 30) / 3,
              getTitlesWidget: (value, meta) {
                if ((value - spots.first.x).abs() > .6 &&
                    (value - spots.last.x).abs() > .6 &&
                    meta.appliedInterval == 0) {
                  return const SizedBox.shrink();
                }
                final date = DateTime.fromMillisecondsSinceEpoch(
                  (value * Duration.millisecondsPerDay).round(),
                  isUtc: true,
                );
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('dd/MM').format(date),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (items) => items
                .map(
                  (item) => LineTooltipItem(
                    '${item.y.toStringAsFixed(1)} ${unit.weightSymbol}\n'
                    '${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch((item.x * Duration.millisecondsPerDay).round(), isUtc: true))}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
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
}

class _TrendSummary extends StatelessWidget {
  const _TrendSummary({required this.entries, required this.unit});

  final List<WeightEntry> entries;
  final MeasurementUnitSystem unit;

  @override
  Widget build(BuildContext context) {
    final deltaKg = entries.last.weightKg - entries.first.weightKg;
    final delta = unit.weightFromKilograms(deltaKg.abs());
    final direction = deltaKg > .01
        ? 'Tăng'
        : deltaKg < -.01
        ? 'Giảm'
        : 'Ổn định';
    final icon = deltaKg > .01
        ? Icons.trending_up
        : deltaKg < -.01
        ? Icons.trending_down
        : Icons.trending_flat;
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$direction ${delta.toStringAsFixed(1)} ${unit.weightSymbol} • '
            '${entries.length} ngày có dữ liệu',
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}
