import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_assistant_sheet.dart';

class AiFloatingButton extends ConsumerStatefulWidget {
  const AiFloatingButton({super.key});

  @override
  ConsumerState<AiFloatingButton> createState() => _AiFloatingButtonState();
}

class _AiFloatingButtonState extends ConsumerState<AiFloatingButton> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest) {
      _animController.repeat(reverse: true);
    }
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (ctx, child) {
        return Transform.scale(
          scale: _pulse.value,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: () => AiAssistantSheet.show(context),
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 18 : 14,
              vertical: isDesktop ? 12 : 10,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isDesktop ? 'AI Assistant' : 'Ask AI',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
