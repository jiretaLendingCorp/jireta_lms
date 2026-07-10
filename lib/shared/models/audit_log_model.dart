// lib/shared/models/audit_log_model.dart
// Updated to include actorName, actorRole, description from migration 009.
class AuditLogModel {
  final String id;
  final String userId;
  final String? userName;    // legacy field
  final String? actorName;   // full name from trigger
  final String? actorRole;   // role from trigger
  final String? description; // human-readable description from trigger
  final String action;
  final String tableName;
  final String? recordId;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final String? ipAddress;
  final String? userAgent;
  final DateTime createdAt;

  const AuditLogModel({
    required this.id,
    required this.userId,
    this.userName,
    this.actorName,
    this.actorRole,
    this.description,
    required this.action,
    required this.tableName,
    this.recordId,
    this.oldValues,
    this.newValues,
    this.ipAddress,
    this.userAgent,
    required this.createdAt,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) => AuditLogModel(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    userName: json['user_name'] as String?,
    actorName: json['actor_name'] as String?,
    actorRole: json['actor_role'] as String?,
    description: json['description'] as String?,
    action: json['action'] as String,
    tableName: json['table_name'] as String,
    recordId: json['record_id'] as String?,
    oldValues: json['old_values'] as Map<String, dynamic>?,
    newValues: json['new_values'] as Map<String, dynamic>?,
    ipAddress: json['ip_address'] as String?,
    userAgent: json['user_agent'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}