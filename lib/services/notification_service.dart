import 'package:flutter/foundation.dart';

import '../models/health_models.dart';

class NotificationService {
  ValueChanged<String>? _payloadHandler;

  void setPayloadHandler(ValueChanged<String> handler) {
    _payloadHandler = handler;
  }

  Future<void> initialize() async {}

  Future<bool> requestPermission() async => true;

  Future<bool> openNotificationSettings() async => false;

  Future<void> initializeFirebaseMessaging({
    required bool Function() isEnabled,
  }) async {}

  Future<void> schedule(WorkoutReminder reminder) async {}

  Future<void> cancel(String reminderId) async {}

  Future<void> scheduleProgramOccurrence({
    required String occurrenceId,
    required String title,
    required DateTime scheduledAt,
    required int minutesBefore,
  }) async {}

  Future<void> scheduleRestEnd({
    required String sessionId,
    required String phaseId,
    required DateTime restEndsAt,
  }) async {}

  Future<void> cancelRest({
    required String sessionId,
    required String phaseId,
  }) async {}

  Future<void> cancelRestSession(String sessionId) async {}

  Future<void> cancelProgramOccurrence(String occurrenceId) async {}

  Future<void> cancelAll() async {}

  @visibleForTesting
  void dispatchForTesting(String payload) => _payloadHandler?.call(payload);
}
