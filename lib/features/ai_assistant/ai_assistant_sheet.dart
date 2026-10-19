import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';
import '../../services/ai/ai_action_service.dart';
import '../../services/ai/ai_confirmation_manager.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/speech_service.dart';

class AiAssistantSheet extends ConsumerStatefulWidget {
  const AiAssistantSheet({super.key});

  static Future<void> show(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (isDesktop) {
      return showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => const Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: SizedBox(
            width: 540,
            height: 720,
            child: AiAssistantSheet(),
          ),
        ),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const FractionallySizedBox(
          heightFactor: 0.90,
          child: AiAssistantSheet(),
        ),
      );
    }
  }

  @override
  ConsumerState<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends ConsumerState<AiAssistantSheet> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AiMessage> _messages = [];

  bool _isListening = false;
  String _liveTranscript = '';
  bool _isSpeakingMuted = false;
  bool _isProcessing = false;
  String? _pendingConfirmationToken;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initial greeting
    _messages.add(
      AiMessage(
        isUser: false,
        text: 'Namaste! I am your Mehta AI Voice Assistant. Speak or type any command to manage menu items, bulk import dishes, occupy tables, check revenue, record customer Khata, or dispatch orders.',
        actionResult: const AiActionResult(
          type: AiActionType.generalHelp,
          success: true,
          title: 'Ready for Operations Commands',
          description: 'Try: "Add Paneer Lababdar for 280 in Main Course", "What is today\'s sales?", "Occupy Table 3 for 4 guests", or "Suresh paid 500 rupees".',
          icon: Icons.auto_awesome,
          color: Color(0xFF6366F1),
          isDatabaseSynced: false,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    SpeechService.stopListening();
    SpeechService.stopSpeaking();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleListening() {
    if (_isListening) {
      SpeechService.stopListening();
      setState(() => _isListening = false);
      if (_liveTranscript.trim().isNotEmpty) {
        _submitPrompt(_liveTranscript.trim());
        _liveTranscript = '';
      }
    } else {
      SpeechService.stopSpeaking();
      setState(() {
        _isListening = true;
        _liveTranscript = '';
      });

      final started = SpeechService.startListening(
        onResult: (text, isFinal) {
          if (!mounted) return;
          setState(() {
            _liveTranscript = text;
          });
          if (isFinal && text.trim().isNotEmpty) {
            SpeechService.stopListening();
            setState(() => _isListening = false);
            _submitPrompt(text.trim());
            _liveTranscript = '';
          }
        },
        onEnd: () {
          if (!mounted) return;
          if (_isListening) {
            setState(() => _isListening = false);
            if (_liveTranscript.trim().isNotEmpty) {
              _submitPrompt(_liveTranscript.trim());
              _liveTranscript = '';
            }
          }
        },
        onError: (err) {
          if (!mounted) return;
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Voice input notice: $err. You can also type commands directly.'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      );

      if (!started && mounted) {
        setState(() => _isListening = false);
      }
    }
  }

  Future<void> _submitPrompt(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    final currentStaff = ref.read(currentStaffProvider);
    _textController.clear();

    setState(() {
      _messages.add(AiMessage(isUser: true, text: clean));
      _isProcessing = true;
    });
    _scrollToBottom();

    try {
      final res = await AiAssistantService.executeCommand(
        prompt: clean,
        ref: ref,
        staff: currentStaff,
        pendingToken: _pendingConfirmationToken,
      );

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        if (res.actionResult?.requiresConfirmation == true && res.actionResult?.confirmationToken != null) {
          _pendingConfirmationToken = res.actionResult!.confirmationToken;
        } else {
          _pendingConfirmationToken = null;
        }

        _messages.add(
          AiMessage(
            isUser: false,
            text: res.replyText,
            actionResult: res.actionResult,
          ),
        );
      });
      _scrollToBottom();

      // Speak reply if not muted
      if (!_isSpeakingMuted) {
        SpeechService.speak(res.replyText);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _messages.add(
          AiMessage(
            isUser: false,
            text: 'An error occurred while executing this command: $e',
          ),
        );
      });
      _scrollToBottom();
    }
  }

  Future<void> _confirmAction(String token) async {
    final currentStaff = ref.read(currentStaffProvider);
    setState(() {
      _isProcessing = true;
    });
    _scrollToBottom();

    try {
      final execRes = await AiActionService.executeConfirmedAction(
        confirmationToken: token,
        staff: currentStaff,
        ref: ref,
      );

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _pendingConfirmationToken = null;
        _messages.add(
          AiMessage(
            isUser: false,
            text: execRes.summary,
            actionResult: AiActionResult(
              type: AiActionType.unknown,
              success: execRes.success,
              title: execRes.success ? 'Action Executed' : 'Execution Failed',
              description: execRes.summary,
              icon: execRes.success ? Icons.cloud_done_rounded : Icons.error_outline_rounded,
              color: execRes.success ? const Color(0xFF10B981) : Colors.red,
              isDatabaseSynced: execRes.success,
              requiresConfirmation: false,
            ),
          ),
        );
      });
      _scrollToBottom();

      if (!_isSpeakingMuted) {
        SpeechService.speak(execRes.summary);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _pendingConfirmationToken = null;
        _messages.add(
          AiMessage(
            isUser: false,
            text: 'Error executing confirmed action: $e',
          ),
        );
      });
      _scrollToBottom();
    }
  }

  void _cancelAction(String token) {
    AiConfirmationManager.cancelToken(token);
    setState(() {
      _pendingConfirmationToken = null;
      _messages.add(
        AiMessage(
          isUser: false,
          text: 'Action cancelled. No database changes were made.',
          actionResult: const AiActionResult(
            type: AiActionType.unknown,
            success: true,
            title: 'Action Cancelled',
            description: 'Operation discarded by user.',
            icon: Icons.cancel_outlined,
            color: Colors.grey,
            isDatabaseSynced: false,
            requiresConfirmation: false,
          ),
        ),
      );
    });
    _scrollToBottom();
    if (!_isSpeakingMuted) {
      SpeechService.speak('Action cancelled.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentStaff = ref.watch(currentStaffProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161719) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)).add(
          const BorderRadius.all(Radius.circular(24)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isDark ? const Color(0xFF2C2D31) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Header Bar
            _buildHeader(isDark, currentStaff),

            // Quick Suggestion Chips
            _buildSuggestionChips(isDark),

            // Chat Feed
            Expanded(
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) => _buildMessageBubble(_messages[i], isDark),
                  ),
                  if (_isProcessing)
                    Positioned(
                      bottom: 8,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF222428) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                            ),
                            SizedBox(width: 8),
                            Text('Processing verified command...', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Live voice waveform preview (when listening)
            if (_isListening) _buildLiveVoiceWaveform(isDark),

            // Input Bar (Voice Orb + Text field)
            _buildInputBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, StaffMember currentStaff) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2024) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2C2D31) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Mehta AI Assistant',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                      child: const Text(
                        'VOICE LIVE',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${currentStaff.name} (${currentStaff.roleDisplayName}) • Full Database Powers',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          // Speaker mute toggle
          IconButton(
            icon: Icon(
              _isSpeakingMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              size: 20,
              color: _isSpeakingMuted ? Colors.grey : const Color(0xFF6366F1),
            ),
            tooltip: _isSpeakingMuted ? 'Unmute AI Voice' : 'Mute AI Voice',
            onPressed: () {
              setState(() {
                _isSpeakingMuted = !_isSpeakingMuted;
                SpeechService.isSpeakingEnabled = !_isSpeakingMuted;
                if (_isSpeakingMuted) SpeechService.stopSpeaking();
              });
            },
          ),
          // Close button
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips(bool isDark) {
    final suggestions = [
      (label: '🍽️ Add Paneer Tikka 260', prompt: 'Add Paneer Tikka for 260 in Starters'),
      (label: '💰 Today\'s Revenue', prompt: 'What is today\'s sales?'),
      (label: '🪑 Occupy Table 3', prompt: 'Occupy Table 3 for 4 guests'),
      (label: '🚫 Out of Stock', prompt: 'Mark Dal Makhani as out of stock'),
      (label: '🧑‍🍳 Active Orders', prompt: 'How many orders are pending in kitchen?'),
      (label: '📒 Check Balance', prompt: 'What is Suresh\'s balance?'),
      (label: '🏆 Top Dishes', prompt: 'What are our top selling dishes?'),
    ];

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final s = suggestions[i];
          return ActionChip(
            label: Text(s.label, style: const TextStyle(fontSize: 11.5)),
            backgroundColor: isDark ? const Color(0xFF222428) : const Color(0xFFF1F5F9),
            side: BorderSide(
              color: isDark ? const Color(0xFF2C2D31) : const Color(0xFFE2E8F0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            onPressed: () => _submitPrompt(s.prompt),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(AiMessage msg, bool isDark) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            msg.text,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
          ),
        ),
      );
    }

    // AI Message
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF222428) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(
                  color: isDark ? const Color(0xFF2C2D31) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ),

            // Action Card (or Confirmation Preview Card)
            if (msg.actionResult != null) ...[
              const SizedBox(height: 6),
              if (msg.actionResult!.requiresConfirmation && msg.actionResult!.confirmationToken != null)
                _buildConfirmationCard(msg.actionResult!, isDark)
              else
                _buildActionCard(msg.actionResult!, isDark),
            ],
          ],
        ),
      ),
    );
  }

  /// Interactive Confirmation Card with Preview, Diff, and Approve/Cancel actions
  Widget _buildConfirmationCard(AiActionResult action, bool isDark) {
    final preview = action.previewData;
    final token = action.confirmationToken ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2129) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.security_rounded, color: Color(0xFF10B981), size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'CONFIRMATION REQUIRED',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Structured Preview Content
          _buildPreviewContent(preview, isDark),

          const SizedBox(height: 12),
          // Action Buttons: Approve & Execute / Cancel
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmAction(token),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Approve & Execute', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelAction(token),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Voice enabled: Say "Confirm" or "Cancel"',
              style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContent(Map<String, dynamic> preview, bool isDark) {
    final type = preview['preview_type']?.toString();

    if (type == 'menu_item_create') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262A34) : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            _diffRow('Dish Name', preview['name']?.toString() ?? ''),
            _diffRow('Category', preview['category']?.toString() ?? ''),
            _diffRow('Price', '₹${(preview['price'] as num?)?.toStringAsFixed(0) ?? "0"}'),
            _diffRow('Dietary', (preview['is_veg'] as bool? ?? true) ? '🟢 Vegetarian' : '🔴 Non-Vegetarian'),
            if (preview['is_duplicate'] == true) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'A dish with this name exists. Confirming will add another entry.',
                        style: TextStyle(fontSize: 10.5, color: Colors.amber),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (type == 'menu_item_update') {
      final diff = preview['diff'] as Map<String, dynamic>? ?? {};
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262A34) : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dish: ${preview['item_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const Divider(height: 12),
            if (diff.containsKey('price'))
              _diffRow('Price', '₹${diff['price']['old']} ➔ ₹${diff['price']['new']}'),
            if (diff.containsKey('is_available'))
              _diffRow('Status', '${diff['is_available']['old'] ? "In Stock" : "Out"} ➔ ${diff['is_available']['new'] ? "In Stock" : "Out"}'),
            if (diff.containsKey('category'))
              _diffRow('Category', '${diff['category']['old']} ➔ ${diff['category']['new']}'),
          ],
        ),
      );
    }

    if (type == 'bulk_menu_import') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262A34) : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            _diffRow('Total Dishes Parsed', '${preview['total_parsed']}'),
            _diffRow('Existing Names Detected', '${preview['duplicates']}'),
            _diffRow('Import Mode', '${preview['mode']}'),
          ],
        ),
      );
    }

    if (type == 'table_status_change') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262A34) : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            _diffRow('Table', 'Table ${preview['table_number']}'),
            _diffRow('Action', '${preview['action']}'.toUpperCase()),
            _diffRow('Guests', '${preview['guests']} pax'),
          ],
        ),
      );
    }

    if (type == 'payment_settlement') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262A34) : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            _diffRow('Customer', '${preview['customer_name']}'),
            _diffRow('Amount Received', '₹${preview['amount']} (${preview['payment_mode']})'),
            _diffRow('Khata Balance', '₹${preview['old_balance']} ➔ ₹${preview['new_balance']}'),
          ],
        ),
      );
    }

    // Default fallback preview
    return Text(
      preview.toString(),
      style: const TextStyle(fontSize: 11),
    );
  }

  Widget _diffRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionCard(AiActionResult action, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1C20) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: action.color.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: action.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(action.icon, color: action.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        action.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    if (action.isDatabaseSynced)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_done_rounded, size: 11, color: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Text(
                              'SUPABASE LIVE',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  action.description,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveVoiceWaveform(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
      child: Row(
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _liveTranscript.isEmpty ? 'Listening... Speak your restaurant command now' : '"$_liveTranscript"',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _toggleListening,
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2024) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2C2D31) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Voice Microphone Button (Pulse when listening)
            GestureDetector(
              onTap: _toggleListening,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (ctx, child) {
                  return Transform.scale(
                    scale: _isListening ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: _isListening
                            ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF97316)])
                            : const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? const Color(0xFFEF4444) : const Color(0xFF6366F1))
                                .withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(width: 10),

            // Text input field
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF26282D) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: isDark ? const Color(0xFF33353A) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: TextField(
                  controller: _textController,
                  onSubmitted: _submitPrompt,
                  decoration: InputDecoration(
                    hintText: 'Speak or type: "Add dish", "Sales", "Occupy table"...',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Send Button
            IconButton(
              icon: const Icon(Icons.send_rounded, size: 20, color: Color(0xFF6366F1)),
              tooltip: 'Send Command',
              onPressed: () => _submitPrompt(_textController.text),
            ),
          ],
        ),
      ),
    );
  }
}
