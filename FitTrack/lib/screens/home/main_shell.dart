import 'package:flutter/material.dart';

import '../../models/active_workout.dart';
import '../../models/program.dart';
import '../../services/notification_service.dart';
import '../../state/app_state.dart';
import '../active/active_workout_screen.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';
import '../program/program_overview_screen.dart';
import 'home_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.state});
  final AppState state;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  var _index = 0;
  var _routingNotification = false;
  String? _preferredOccurrenceId;

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
      final route = decodeFitTrackNotificationPayload(payload);
      if (route == null) return;
      if (route['type'] == 'today') {
        final occurrence = widget.state.occurrenceById(
          route['occurrenceId'] as String,
        );
        if (occurrence == null ||
            !occurrence.isOpen ||
            occurrence.status == WorkoutOccurrenceStatus.inProgress) {
          return;
        }
        if (mounted) {
          setState(() => _preferredOccurrenceId = occurrence.id);
        }
        return;
      }
      if (route['type'] != 'active') return;
      final draft = widget.state.activeWorkoutDraft;
      if (draft == null ||
          draft.phase != WorkoutPhase.resting ||
          draft.sessionId != route['sessionId'] ||
          draft.phaseId != route['phaseId'] ||
          draft.restEndsAt?.millisecondsSinceEpoch != route['restEndsAt']) {
        return;
      }
      final occurrence = widget.state.occurrenceById(draft.occurrenceId);
      if (occurrence == null ||
          occurrence.status != WorkoutOccurrenceStatus.inProgress) {
        return;
      }
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
      HomeScreen(
        state: widget.state,
        preferredOccurrenceId: _preferredOccurrenceId,
        onOpenProgram: () => setState(() => _index = 1),
        onOpenProfile: () => setState(() => _index = 3),
        onOpenHistory: () => setState(() => _index = 2),
      ),
      ProgramOverviewScreen(state: widget.state),
      HistoryScreen(state: widget.state),
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
