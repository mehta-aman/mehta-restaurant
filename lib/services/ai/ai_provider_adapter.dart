import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import 'ai_models.dart';

/// Response returned from an AI Orchestrator
class AiOrchestratorResponse {
  final String textResponse;
  final List<AiToolCall> toolCalls;
  final List<AiToolResult> toolResults;
  final bool requiresConfirmation;

  const AiOrchestratorResponse({
    required this.textResponse,
    this.toolCalls = const [],
    this.toolResults = const [],
    this.requiresConfirmation = false,
  });
}

/// Abstract adapter interface allowing interchangeable AI orchestrator backends
abstract class AiProviderAdapter {
  String get providerName;

  /// Processes natural language text with session-verified caller identity
  Future<AiOrchestratorResponse> processMessage({
    required String message,
    required StaffMember staff,
    required WidgetRef ref,
    List<Map<String, String>> conversationContext = const [],
  });

  /// Executes a single prepared tool call with parameter and permission validation
  Future<AiToolResult> executeToolCall({
    required AiToolCall toolCall,
    required StaffMember staff,
    required WidgetRef ref,
  });
}
