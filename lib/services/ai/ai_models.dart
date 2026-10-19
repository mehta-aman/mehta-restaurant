import 'package:flutter/foundation.dart';
import '../../models/models.dart';

/// Supported types of tools in the AI Operations Registry
enum AiToolCategory {
  readOnly,
  actionPreparation,
  actionExecution,
}

/// Execution risk level of an action
enum AiRiskLevel {
  low,      // Table status, draft order additions
  medium,   // Adding new menu item, customer creation, stock toggle
  high,     // Price change, Khata credit, payment recording
  critical, // Invoice finalization, invoice voiding, bulk menu import, settings update
}

/// Definition of an AI Tool in the registry with strict JSON schema
@immutable
class AiToolDefinition {
  final String name;
  final String description;
  final AiToolCategory category;
  final AiRiskLevel riskLevel;
  final Set<StaffRole> allowedRoles;
  final Map<String, dynamic> parameterSchema;

  const AiToolDefinition({
    required this.name,
    required this.description,
    required this.category,
    required this.riskLevel,
    required this.allowedRoles,
    required this.parameterSchema,
  });

  bool isAuthorizedFor(StaffRole role) => allowedRoles.contains(role);
}

/// Structured tool call requested by the orchestrator / model
class AiToolCall {
  final String toolName;
  final Map<String, dynamic> arguments;
  final String? callId;

  const AiToolCall({
    required this.toolName,
    required this.arguments,
    this.callId,
  });

  Map<String, dynamic> toJson() => {
    'tool': toolName,
    'arguments': arguments,
    if (callId != null) 'call_id': callId,
  };
}

/// Structured result returned from tool execution
class AiToolResult {
  final String toolName;
  final bool success;
  final String summary;
  final Map<String, dynamic> data;
  final String? errorMessage;
  final AiActionConfirmationToken? confirmationToken;

  const AiToolResult({
    required this.toolName,
    required this.success,
    required this.summary,
    this.data = const {},
    this.errorMessage,
    this.confirmationToken,
  });

  bool get requiresConfirmation => confirmationToken != null;

  Map<String, dynamic> toJson() => {
    'tool': toolName,
    'success': success,
    'summary': summary,
    'data': data,
    if (errorMessage != null) 'error': errorMessage,
    if (confirmationToken != null) 'confirmation_token': confirmationToken!.toJson(),
  };
}

/// Short-lived confirmation token tied to the user, operation, arguments, and database snapshot
class AiActionConfirmationToken {
  final String token;
  final String operationName;
  final Map<String, dynamic> validatedParameters;
  final String staffId;
  final StaffRole staffRole;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final Map<String, dynamic> stateSnapshot;

  AiActionConfirmationToken({
    required this.token,
    required this.operationName,
    required this.validatedParameters,
    required this.staffId,
    required this.staffRole,
    required this.issuedAt,
    required this.expiresAt,
    this.stateSnapshot = const {},
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
    'token': token,
    'operation': operationName,
    'parameters': validatedParameters,
    'staff_id': staffId,
    'staff_role': staffRole.name,
    'issued_at': issuedAt.toIso8601String(),
    'expires_at': expiresAt.toIso8601String(),
    'state_snapshot': stateSnapshot,
  };
}

/// Audit log record for every AI interaction and action
class AiAuditLogEntry {
  final String id;
  final DateTime timestamp;
  final String staffId;
  final String staffName;
  final StaffRole staffRole;
  final String toolName;
  final Map<String, dynamic> arguments;
  final bool success;
  final String? errorMessage;
  final String? userPrompt;
  final String? confirmationToken;

  const AiAuditLogEntry({
    required this.id,
    required this.timestamp,
    required this.staffId,
    required this.staffName,
    required this.staffRole,
    required this.toolName,
    required this.arguments,
    required this.success,
    this.errorMessage,
    this.userPrompt,
    this.confirmationToken,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'staff_id': staffId,
    'staff_name': staffName,
    'staff_role': staffRole.name,
    'tool_name': toolName,
    'arguments': arguments,
    'success': success,
    if (errorMessage != null) 'error_message': errorMessage,
    if (userPrompt != null) 'user_prompt': userPrompt,
    if (confirmationToken != null) 'confirmation_token': confirmationToken,
  };
}
