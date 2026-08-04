import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi');

  var firebaseAvailable = false;
  try {
    await Firebase.initializeApp();
    firebaseAvailable = true;
  } on Object {
    // Keep local development available on platforms without Firebase config.
  }

  final notifications = NotificationService();
  await notifications.initialize();

  final state = AppState(
    firebaseAvailable: firebaseAvailable,
    notificationService: notifications,
  );
  await state.initialize();

  runApp(FitTrackApp(state: state));
}
