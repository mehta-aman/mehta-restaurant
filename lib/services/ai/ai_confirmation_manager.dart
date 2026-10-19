import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import 'ai_models.dart';

class AiConfirmationManager {
  static const _uuid = Uuid();
  static final Map<String, AiActionConfirmationToken> _activeTokens = {};

  /// Creates and stores an expiring confirmation token
  static AiActionConfirmationToken issueToken({
    required String operationName,
    required Map<String, dynamic> validatedParameters,
    required StaffMember staff,
    Duration validity = const Duration(minutes: 5),
    Map<String, dynamic> stateSnapshot = const {},
  }) {
    // Purge expired tokens first
    purgeExpired();

    final tokenStr = 'act_${_uuid.v4().replaceAll('-', '')}';
    final now = DateTime.now();
    final token = AiActionConfirmationToken(
      token: tokenStr,
      operationName: operationName,
      validatedParameters: Map<String, dynamic>.unmodifiable(validatedParameters),
      staffId: staff.id,
      staffRole: staff.role,
      issuedAt: now,
      expiresAt: now.add(validity),
      stateSnapshot: Map<String, dynamic>.unmodifiable(stateSnapshot),
    );

    _activeTokens[tokenStr] = token;
    return token;
  }

  /// Peeks at an active token without consuming it
  static AiActionConfirmationToken? peekToken(String tokenString) {
    return _activeTokens[tokenString];
  }

  /// Verifies a confirmation token and consumes it (single-use protection against replay)
  static ({bool isValid, String? error, AiActionConfirmationToken? token}) consumeToken({
    required String tokenString,
    required StaffMember staff,
    String? expectedOperation,
  }) {
    final token = _activeTokens[tokenString];
    if (token == null) {
      return (
        isValid: false,
        error: 'Confirmation token is invalid or has already been used.',
        token: null,
      );
    }

    if (token.isExpired) {
      _activeTokens.remove(tokenString);
      return (
        isValid: false,
        error: 'Confirmation token has expired. Please re-issue the command to preview current data.',
        token: null,
      );
    }

    if (expectedOperation != null && expectedOperation.isNotEmpty && token.operationName != expectedOperation) {
      return (
        isValid: false,
        error: 'Token operation mismatch: issued for "${token.operationName}" but received "$expectedOperation".',
        token: null,
      );
    }

    // Role and caller integrity check
    if (token.staffId != staff.id && staff.role != StaffRole.owner) {
      return (
        isValid: false,
        error: 'Security Error: This action was prepared by another staff member and cannot be confirmed without Owner privilege.',
        token: null,
      );
    }

    // Single-use consumption
    _activeTokens.remove(tokenString);

    return (
      isValid: true,
      error: null,
      token: token,
    );
  }

  /// Explicitly cancels a pending confirmation token
  static bool cancelToken(String tokenString) {
    return _activeTokens.remove(tokenString) != null;
  }

  /// Cleans up stale tokens
  static void purgeExpired() {
    final now = DateTime.now();
    _activeTokens.removeWhere((_, token) => now.isAfter(token.expiresAt));
  }

  /// Testing helper to inspect active tokens count
  static int get activeTokenCount => _activeTokens.length;

  /// Clear all tokens (useful for test tearDown)
  static void clearAll() => _activeTokens.clear();
}
