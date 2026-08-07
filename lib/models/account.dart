enum AccountStatus { active, suspended, deletionPending, deleted }

enum AccountJobStatus {
  requested,
  processing,
  ready,
  completed,
  failed,
  expired,
  cancelled,
}

class AccountAccess {
  const AccountAccess({required this.status, this.reason, this.updatedAt});

  const AccountAccess.active()
    : status = AccountStatus.active,
      reason = null,
      updatedAt = null;

  final AccountStatus status;
  final String? reason;
  final DateTime? updatedAt;

  bool get canUsePrivateApp => status == AccountStatus.active;
}

class DataExportRequest {
  const DataExportRequest({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.updatedAt,
    this.storagePath,
    this.expiresAt,
    this.failureReason,
  });

  final String id;
  final AccountJobStatus status;
  final DateTime requestedAt;
  final DateTime? updatedAt;
  final String? storagePath;
  final DateTime? expiresAt;
  final String? failureReason;

  bool get canDownload =>
      status == AccountJobStatus.ready &&
      storagePath != null &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  bool get isPending =>
      status == AccountJobStatus.requested ||
      status == AccountJobStatus.processing;

  factory DataExportRequest.fromJson(String id, Map<String, dynamic> json) =>
      DataExportRequest(
        id: id,
        status: accountJobStatusFromStored(json['status'] as String?),
        requestedAt: _date(json['requestedAt']) ?? DateTime.now(),
        updatedAt: _date(json['updatedAt']),
        storagePath: json['storagePath'] as String?,
        expiresAt: _date(json['expiresAt']),
        failureReason: json['failureReason'] as String?,
      );
}

class AccountDeletionRequest {
  const AccountDeletionRequest({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.updatedAt,
    this.failureReason,
  });

  final String id;
  final AccountJobStatus status;
  final DateTime requestedAt;
  final DateTime? updatedAt;
  final String? failureReason;

  bool get isPending =>
      status == AccountJobStatus.requested ||
      status == AccountJobStatus.processing;

  factory AccountDeletionRequest.fromJson(
    String id,
    Map<String, dynamic> json,
  ) => AccountDeletionRequest(
    id: id,
    status: accountJobStatusFromStored(json['status'] as String?),
    requestedAt: _date(json['requestedAt']) ?? DateTime.now(),
    updatedAt: _date(json['updatedAt']),
    failureReason: json['failureReason'] as String?,
  );
}

class AccountAccessException implements Exception {
  const AccountAccessException(this.access);

  final AccountAccess access;

  @override
  String toString() => switch (access.status) {
    AccountStatus.suspended => access.reason ?? 'Tài khoản đang bị tạm khóa.',
    AccountStatus.deletionPending => 'Tài khoản đang chờ hoàn tất yêu cầu xóa.',
    AccountStatus.deleted => 'Tài khoản đã bị xóa.',
    AccountStatus.active => 'Tài khoản đang hoạt động.',
  };
}

AccountStatus accountStatusFromStored(String? value) => switch (value) {
  'suspended' || 'locked' => AccountStatus.suspended,
  'deletion_pending' || 'deletionPending' => AccountStatus.deletionPending,
  'deleted' || 'disabled' => AccountStatus.deleted,
  _ => AccountStatus.active,
};

AccountJobStatus accountJobStatusFromStored(String? value) => switch (value) {
  'processing' => AccountJobStatus.processing,
  'ready' => AccountJobStatus.ready,
  'completed' => AccountJobStatus.completed,
  'failed' => AccountJobStatus.failed,
  'expired' => AccountJobStatus.expired,
  'cancelled' => AccountJobStatus.cancelled,
  _ => AccountJobStatus.requested,
};

DateTime? _date(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  try {
    final dynamic timestamp = value;
    return timestamp.toDate() as DateTime;
  } on Object {
    return null;
  }
}
