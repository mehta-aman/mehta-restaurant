import '../../models/models.dart';
import 'ai_models.dart';

class AiPermissionGuard {
  /// Evaluates whether a given staff member is permitted to invoke a tool
  static ({bool isAllowed, String? rejectionReason}) checkPermission({
    required StaffMember staff,
    required AiToolDefinition tool,
    Map<String, dynamic> arguments = const {},
  }) {
    // 1. Role-based check against tool definition
    if (!tool.isAuthorizedFor(staff.role)) {
      final allowedRoleNames = tool.allowedRoles.map((r) => r.name.toUpperCase()).join(', ');
      return (
        isAllowed: false,
        rejectionReason: 'Access Denied: The "${tool.name}" operation requires one of [$allowedRoleNames] roles. '
            'Your active role is ${staff.role.name.toUpperCase()} (${staff.name}).',
      );
    }

    // 2. High-risk parameter-level inspections
    if (tool.name == 'prepare_settings_update') {
      final hasTaxChanges = arguments.containsKey('gst_enabled') ||
          arguments.containsKey('tax_rate') ||
          arguments.containsKey('gstin') ||
          arguments.containsKey('invoice_prefix') ||
          arguments.containsKey('next_invoice_number');

      if (hasTaxChanges && staff.role != StaffRole.owner) {
        return (
          isAllowed: false,
          rejectionReason: 'Access Denied: Modifying GST, Tax Rates, or Invoice Sequences requires Owner privileges. '
              'Please ask Aman Mehta (Owner) to authorize this modification.',
        );
      }
    }

    if (tool.name == 'prepare_invoice_void') {
      if (staff.role != StaffRole.owner && staff.role != StaffRole.manager) {
        return (
          isAllowed: false,
          rejectionReason: 'Access Denied: Voiding finalized invoices is strictly restricted to Owner and Manager roles.',
        );
      }
    }

    if (tool.name == 'prepare_customer_balance_entry') {
      // Adding manual credit balance without invoice
      if (staff.role != StaffRole.owner && staff.role != StaffRole.manager) {
        return (
          isAllowed: false,
          rejectionReason: 'Access Denied: Adjusting customer opening balances directly requires Owner or Manager authorization.',
        );
      }
    }

    return (isAllowed: true, rejectionReason: null);
  }

  /// Builds a secure audit log for permission denials without leaking sensitive data
  static AiAuditLogEntry createDenialLog({
    required StaffMember staff,
    required String toolName,
    required Map<String, dynamic> arguments,
    required String reason,
    String? userPrompt,
  }) {
    // Sanitize arguments to avoid logging PINs or secrets
    final sanitizedArgs = Map<String, dynamic>.from(arguments);
    sanitizedArgs.removeWhere((k, v) => k.toLowerCase().contains('pin') || k.toLowerCase().contains('secret') || k.toLowerCase().contains('password'));

    return AiAuditLogEntry(
      id: 'denial_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      staffId: staff.id,
      staffName: staff.name,
      staffRole: staff.role,
      toolName: toolName,
      arguments: sanitizedArgs,
      success: false,
      errorMessage: reason,
      userPrompt: userPrompt,
    );
  }
}
