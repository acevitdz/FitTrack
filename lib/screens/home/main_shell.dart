import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../active/active_workout_screen.dart';
import '../history/progress_screen.dart';
import '../profile/profile_screen.dart';
import '../program/program_overview_screen.dart';
import 'dashboard_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.state});
  final AppState state;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  var _index = 0;
  var _routingNotification = false;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeNotification());
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted || _routingNotification) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeNotification());
  }

  Future<void> _routeNotification() async {
    if (!mounted || _routingNotification) return;
    final payload = widget.state.takePendingNotificationPayload();
    if (payload == null) return;
    _routingNotification = true;
    setState(() => _index = 0);
    try {
      if (!payload.startsWith('active:')) return;
      final draft = widget.state.activeWorkoutDraft;
      if (draft == null) return;
      final occurrence = widget.state.occurrences
          .where((item) => item.id == draft.occurrenceId)
          .firstOrNull;
      if (occurrence == null) return;
      final controller = await widget.state.openWorkout(occurrence);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveWorkoutScreen(
            state: widget.state,
            controller: controller,
            onOpenHistory: () => setState(() => _index = 2),
          ),
        ),
      );
    } finally {
      _routingNotification = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        state: widget.state,
        onOpenProgram: () => setState(() => _index = 1),
        onOpenProfile: () => setState(() => _index = 3),
        onOpenHistory: () => setState(() => _index = 2),
      ),
      ProgramOverviewScreen(state: widget.state),
      ProgressScreen(state: widget.state),
      ProfileScreen(state: widget.state),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Chương trình',
          ),
          NavigationDestination(
            icon: Icon(Icons.query_stats_outlined),
            selectedIcon: Icon(Icons.query_stats),
            label: 'Tiến độ',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }
}
