import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';

class LegacyDataScreen extends StatelessWidget {
  const LegacyDataScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dữ liệu phiên bản cũ')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          color: AppColors.warning.withValues(alpha: .12),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Dữ liệu này chỉ được giữ để tham khảo. Bạn không thể sửa, nhân bản, lên lịch hoặc dùng nó để tạo kết quả mới.',
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Kế hoạch thủ công cũ',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (state.plans.isEmpty)
          const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Không có kế hoạch cũ',
            message: 'Không tìm thấy dữ liệu plan từ phiên bản trước.',
          )
        else
          for (final plan in state.plans)
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(plan.name),
                subtitle: Text('${plan.exercises.length} bài • chỉ đọc'),
                children: [
                  for (final exercise in plan.exercises)
                    ListTile(
                      title: Text(exercise.exerciseName),
                      subtitle: const Text('Prescription legacy đã lưu'),
                    ),
                ],
              ),
            ),
        const SizedBox(height: 20),
        Text(
          'Kết quả thủ công cũ',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (state.completions.isEmpty)
          const Text('Không có kết quả legacy.')
        else
          for (final completion in state.completedCompletions)
            Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: Text(completion.planSnapshot.name),
                subtitle: Text(
                  '${DateFormat('dd/MM/yyyy').format(completion.completedAt)} • dữ liệu tự nhập cũ',
                ),
                trailing: const Icon(Icons.lock_outline),
              ),
            ),
        const SizedBox(height: 18),
        const Text(
          'Số liệu legacy không được trộn với thống kê Active Workout đã xác minh.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    ),
  );
}
