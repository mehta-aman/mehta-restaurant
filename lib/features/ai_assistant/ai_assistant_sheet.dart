import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
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
            width: 520,
            height: 680,
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
          heightFactor: 0.88,
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
        text: 'Namaste! I am your Mehta AI Voice Assistant. Speak or type any command to manage menu items, occupy tables, check today\'s revenue, record customer Khata, or dispatch orders.',
        actionResult: const AiActionResult(
          type: AiActionType.generalHelp,
          success: true,
          title: 'Ready for Voice & Text Commands',
          description: 'Try: "Add Paneer Lababdar for 280 in Main Course", "What is today\'s revenue?", or "Occupy Table 3 for 4 guests".',
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

    _textController.clear();

    setState(() {
      _messages.add(AiMessage(isUser: true, text: clean));
      _isProcessing = true;
    });
    _scrollToBottom();

    try {
      final res = await AiAssistantService.executeCommand(prompt: clean, ref: ref);

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            _buildHeader(isDark),

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
                            Text('Processing & updating Supabase...', style: TextStyle(fontSize: 12)),
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

  Widget _buildHeader(bool isDark) {
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
                  'Connected to Supabase • Full Database Powers',
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
      (label: '🍽️ Add Paneer Lababdar 280', prompt: 'Add Paneer Lababdar for 280 in Main Course'),
      (label: '💰 Today\'s Revenue', prompt: 'What is today\'s sales?'),
      (label: '🪑 Occupy Table 3', prompt: 'Occupy Table 3 for 4 guests'),
      (label: '🚫 Out of Stock', prompt: 'Mark Dal Makhani as out of stock'),
      (label: '🧑‍🍳 Active Orders', prompt: 'How many orders are pending in kitchen?'),
      (label: '📒 Check Balance', prompt: 'What is Suresh\'s balance?'),
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

            // Action Execution Card (if an action took place)
            if (msg.actionResult != null) ...[
              const SizedBox(height: 6),
              _buildActionCard(msg.actionResult!, isDark),
            ],
          ],
        ),
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
                if (action.undoAction != null) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      await action.undoAction!();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Action undone successfully.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Text(
                      'Undo Action ↺',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
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
                    hintText: 'Speak or type: "Add dish", "Sales"...',
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
