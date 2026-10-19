import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';
import '../../services/speech_service.dart';
import '../../services/supabase_service.dart';

class StaffLoginWindow extends ConsumerStatefulWidget {
  final void Function(StaffMember staff)? onLoginSuccess;

  const StaffLoginWindow({super.key, this.onLoginSuccess});

  @override
  ConsumerState<StaffLoginWindow> createState() => _StaffLoginWindowState();
}

class _StaffLoginWindowState extends ConsumerState<StaffLoginWindow> with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  String? _errorMessage;
  bool _isVerifying = false;
  StaffMember? _selectedStaff;
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();
  final FocusNode _keyboardFocusNode = FocusNode();

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    // Auto-focus keyboard for typing PIN immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _shakeController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _onDigitPress(String digit) {
    if (_isVerifying) return;
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
        _errorMessage = null;
      });

      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_isVerifying) return;
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _onClear() {
    if (_isVerifying) return;
    setState(() {
      _enteredPin = '';
      _errorMessage = null;
    });
  }

  Future<void> _verifyPin() async {
    setState(() => _isVerifying = true);

    final staffList = ref.read(staffDirectoryProvider);

    // 1. Online Path: Supabase Server-enforced bcrypt & 5-attempt lockout
    if (SupabaseService.isInitialized) {
      final res = await SupabaseService.verifyStaffPin(pin: _enteredPin);
      if (!mounted) return;
      setState(() => _isVerifying = false);

      if (res.locked) {
        _shake();
        setState(() {
          _enteredPin = '';
          _errorMessage = res.message;
        });
        return;
      }

      if (res.success && res.staff != null) {
        final staffRoleStr = res.staff!['role']?.toString() ?? 'waiter';
        StaffRole resolvedRole = StaffRole.waiter;
        for (final r in StaffRole.values) {
          if (r.name == staffRoleStr) resolvedRole = r;
        }

        final staffMember = StaffMember(
          id: res.staff!['staff_code']?.toString() ?? res.staff!['id']?.toString() ?? 's1',
          name: res.staff!['name']?.toString() ?? 'Staff Member',
          role: resolvedRole,
          pin: _enteredPin,
          avatarIcon: res.staff!['avatar_icon']?.toString() ?? '👤',
        );

        _loginSuccessful(staffMember);
        return;
      }
    }

    // 2. Offline / Local Fallback Path
    setState(() => _isVerifying = false);

    StaffMember? matched;
    if (_selectedStaff != null) {
      if (_selectedStaff!.pin == _enteredPin) {
        matched = _selectedStaff;
      }
    } else {
      matched = staffList.where((s) => s.pin == _enteredPin).firstOrNull;
    }

    if (matched != null) {
      _loginSuccessful(matched);
    } else {
      _shake();
      setState(() {
        _enteredPin = '';
        _errorMessage = _selectedStaff != null
            ? 'Incorrect PIN for ${_selectedStaff!.name}! Please try again.'
            : 'Incorrect PIN! Please try again.';
      });
    }
  }

  void _shake() {
    _shakeController.forward(from: 0.0);
  }

  void _loginSuccessful(StaffMember staff) {
    ref.read(staffSessionProvider.notifier).loginDirect(staff);
    SpeechService.speak('Welcome ${staff.name}!');
    widget.onLoginSuccess?.call(staff);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 950;
    final staffList = ref.watch(staffDirectoryProvider);
    final isCloudConnected = ref.watch(supabaseConnectionProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1012) : const Color(0xFFF1F5F9),
      body: Focus(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
              _onDigitPress('0');
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
              _onDigitPress('1');
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
              _onDigitPress('2');
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
              _onDigitPress('3');
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
              _onDigitPress('4');
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
              _onDigitPress('5');
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
              _onDigitPress('6');
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) {
              _onDigitPress('7');
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) {
              _onDigitPress('8');
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) {
              _onDigitPress('9');
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.backspace) {
              _onBackspace();
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.escape) {
              _onClear();
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
              if (_enteredPin.length == 4) _verifyPin();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: SafeArea(
          child: isDesktop
              ? _buildDesktopLayout(isDark, staffList, isCloudConnected)
              : _buildMobileLayout(isDark, staffList, isCloudConnected),
        ),
      ),
    );
  }

  // ==========================================
  // DESKTOP TWO-COLUMN LAYOUT
  // ==========================================
  Widget _buildDesktopLayout(bool isDark, List<StaffMember> staffList, bool isCloudConnected) {
    return Row(
      children: [
        // Left Column: Branding, Clock & Staff Directory
        Expanded(
          flex: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141619) : Colors.white,
              border: Border(
                right: BorderSide(
                  color: isDark ? const Color(0xFF24272D) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Brand & Clock Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _buildBrandHeader()),
                    const SizedBox(width: 16),
                    _buildLiveClock(isDark, isCloudConnected),
                  ],
                ),
                const SizedBox(height: 36),

                // Section Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Staff Profile',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Click your profile or enter your 4-digit PIN directly',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedStaff != null) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedStaff = null;
                            _enteredPin = '';
                            _errorMessage = null;
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Reset Selection', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),

                // Staff Cards Grid
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 2.3,
                    ),
                    itemCount: staffList.length,
                    itemBuilder: (ctx, i) {
                      final staff = staffList[i];
                      final isSelected = _selectedStaff?.id == staff.id;
                      return _buildStaffProfileCard(staff, isSelected, isDark);
                    },
                  ),
                ),

                // Quick PIN Reference Legend
                _buildPinLegend(isDark),
              ],
            ),
          ),
        ),

        // Right Column: Keypad & PIN Authentication Card
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: _buildPinCard(isDark),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // MOBILE / TABLET VERTICAL LAYOUT
  // ==========================================
  Widget _buildMobileLayout(bool isDark, List<StaffMember> staffList, bool isCloudConnected) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          _buildBrandHeader(),
          const SizedBox(height: 12),
          _buildLiveClock(isDark, isCloudConnected),
          const SizedBox(height: 20),

          // Horizontal scroll of staff profiles
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: staffList.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final staff = staffList[i];
                final isSelected = _selectedStaff?.id == staff.id;
                return SizedBox(
                  width: 170,
                  child: _buildStaffProfileCard(staff, isSelected, isDark),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // PIN Pad Card
          _buildPinCard(isDark),
          const SizedBox(height: 16),
          _buildPinLegend(isDark),
        ],
      ),
    );
  }

  // ==========================================
  // BRAND & CLOCK HEADER
  // ==========================================
  Widget _buildBrandHeader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE11D48), Color(0xFFBE123C), Color(0xFFF59E0B)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        const Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MEHTA RESTAURANT',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                'POS Terminal & Operational Session',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiveClock(bool isDark, bool isCloudConnected) {
    final timeStr = DateFormat('hh:mm:ss a').format(_currentTime);
    final dateStr = DateFormat('EEEE, d MMM yyyy').format(_currentTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          timeStr,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isCloudConnected ? const Color(0xFF10B981) : Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$dateStr • ${isCloudConnected ? "Supabase Live" : "Local POS"}',
              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // STAFF PROFILE CARD
  // ==========================================
  Widget _buildStaffProfileCard(StaffMember staff, bool isSelected, bool isDark) {
    Color roleBadgeColor = const Color(0xFF6366F1);
    if (staff.role == StaffRole.owner) roleBadgeColor = const Color(0xFFE11D48);
    if (staff.role == StaffRole.manager) roleBadgeColor = const Color(0xFFF59E0B);
    if (staff.role == StaffRole.cashier) roleBadgeColor = const Color(0xFF10B981);
    if (staff.role == StaffRole.kitchen) roleBadgeColor = const Color(0xFFF97316);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedStaff = staff;
          _enteredPin = '';
          _errorMessage = null;
        });
        _keyboardFocusNode.requestFocus();
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? roleBadgeColor.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1B1D22) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? roleBadgeColor : (isDark ? const Color(0xFF2C2F36) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: roleBadgeColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF252830) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? roleBadgeColor : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Text(staff.avatarIcon, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    staff.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? (isDark ? Colors.white : Colors.black87) : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleBadgeColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          staff.roleDisplayName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: roleBadgeColor,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const Spacer(),
                        Icon(Icons.check_circle_rounded, color: roleBadgeColor, size: 16),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PIN PAD & AUTHENTICATION CARD
  // ==========================================
  Widget _buildPinCard(bool isDark) {
    return Container(
      width: 380,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181A1F) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2F36) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Target Staff Header
          if (_selectedStaff != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_selectedStaff!.avatarIcon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedStaff!.name} (${_selectedStaff!.roleDisplayName})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            const Icon(Icons.lock_outline_rounded, size: 32, color: Color(0xFF6366F1)),
            const SizedBox(height: 6),
            const Text(
              'Enter Staff PIN',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Type your 4-digit code to log in',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
          ],

          // Animated PIN Circles with Shake on Error
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (ctx, child) {
              return Transform.translate(
                offset: Offset(_shakeAnimation.value * (_shakeController.value < 0.5 ? 1 : -1), 0),
                child: child,
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _enteredPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 9),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? (_errorMessage != null ? Colors.red : const Color(0xFFE11D48))
                        : (isDark ? const Color(0xFF2C2F36) : const Color(0xFFE2E8F0)),
                    border: Border.all(
                      color: isFilled
                          ? (_errorMessage != null ? Colors.red : const Color(0xFFE11D48))
                          : (isDark ? const Color(0xFF40444D) : const Color(0xFFCBD5E1)),
                      width: 2,
                    ),
                    boxShadow: isFilled
                        ? [
                            BoxShadow(
                              color: (_errorMessage != null ? Colors.red : const Color(0xFFE11D48))
                                  .withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),
          ),

          // Error / Status Message
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 14, color: Colors.red),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_isVerifying) ...[
            const SizedBox(height: 12),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE11D48)),
                ),
                SizedBox(width: 8),
                Text('Verifying staff credentials...', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ] else ...[
            const SizedBox(height: 16),
          ],

          // 3x4 Numeric Keypad
          _buildNumericKeypad(isDark),
        ],
      ),
    );
  }

  Widget _buildNumericKeypad(bool isDark) {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3'], isDark),
        const SizedBox(height: 12),
        _buildKeypadRow(['4', '5', '6'], isDark),
        const SizedBox(height: 12),
        _buildKeypadRow(['7', '8', '9'], isDark),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSpecialKey('C', 'Clear', _onClear, isDark, color: Colors.grey),
            const SizedBox(width: 14),
            _buildDigitKey('0', isDark),
            const SizedBox(width: 14),
            _buildSpecialKey('⌫', 'Backspace', _onBackspace, isDark, color: const Color(0xFFE11D48)),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> digits, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < digits.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          _buildDigitKey(digits[i], isDark),
        ],
      ],
    );
  }

  Widget _buildDigitKey(String digit, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onDigitPress(digit),
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF22252C) : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? const Color(0xFF2E323B) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey(
    String symbol,
    String tooltip,
    VoidCallback onTap,
    bool isDark, {
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF22252C) : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? const Color(0xFF2E323B) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Text(
            symbol,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // QUICK PIN LEGEND FOR DEMO / ORIENTATION
  // ==========================================
  Widget _buildPinLegend(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1C21) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2D34) : const Color(0xFFE2E8F0),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Default PINs: Owner (1234) • Manager (9999) • Cashier (2222) • Waiter (1001) • Kitchen (3333)',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
