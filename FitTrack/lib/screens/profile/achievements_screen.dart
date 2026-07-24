import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/seed_data.dart';
import '../../state/app_state.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thành tích')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          mainAxisExtent: 210,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: state.achievements.length,
        itemBuilder: (context, index) {
          final item = state.achievements[index];
          return Card(
            color: item.unlocked
                ? Theme.of(context).colorScheme.tertiaryContainer
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 32,
                    child: Icon(
                      item.unlocked
                          ? SeedData.achievementIcon(item.id)
                          : Icons.lock_outline,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    item.unlocked
                        ? 'Đạt ${DateFormat('dd/MM/yyyy').format(item.unlockedAt!)}'
                        : 'Chưa mở khóa',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
