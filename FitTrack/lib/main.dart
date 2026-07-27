import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi');

  var firebaseAvailable = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseAvailable = true;
  } on Object {
    // Firebase will be enabled automatically after the platform config files
    // are added. The local repository keeps the app usable before that step.
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
