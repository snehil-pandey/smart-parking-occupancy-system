enum IssueStatus { open, inProgress, resolved, rejected }

extension IssueStatusLabel on IssueStatus {
  String get label => switch (this) {
    IssueStatus.open => 'open',
    IssueStatus.inProgress => 'in_progress',
    IssueStatus.resolved => 'resolved',
    IssueStatus.rejected => 'rejected',
  };
}

class IssueReport {
  const IssueReport({
    required this.issueId,
    required this.userId,
    required this.areaId,
    required this.adminId,
    required this.type,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String issueId;
  final String userId;
  final String areaId;
  final String adminId;
  final String type;
  final String message;
  final IssueStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  IssueReport copyWith({
    String? issueId,
    String? userId,
    String? areaId,
    String? adminId,
    String? type,
    String? message,
    IssueStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IssueReport(
      issueId: issueId ?? this.issueId,
      userId: userId ?? this.userId,
      areaId: areaId ?? this.areaId,
      adminId: adminId ?? this.adminId,
      type: type ?? this.type,
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'issueId': issueId,
    'userId': userId,
    'areaId': areaId,
    'adminId': adminId,
    'type': type,
    'message': message,
    'status': status.label,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
