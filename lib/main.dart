import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi');

  final notifications = NotificationService();
  await notifications.initialize();

  final state = AppState(
    firebaseAvailable: false,
    notificationService: notifications,
  );
  await state.initialize();

  runApp(FitTrackApp(state: state));
}
