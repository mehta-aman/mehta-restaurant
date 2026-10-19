import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';
import '../../services/supabase_service.dart';

class StaffSwitchDialog extends ConsumerStatefulWidget {
  const StaffSwitchDialog({super.key});

  @override
  ConsumerState<StaffSwitchDialog> createState() => _StaffSwitchDialogState();
}

class _StaffSwitchDialogState extends ConsumerState<StaffSwitchDialog> {
  String _enteredPin = '';
  String? _errorMessage;
  bool _isVerifying = false;

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

  Future<void> _verifyPin() async {
    setState(() => _isVerifying = true);

    // Online path: Server-enforced bcrypt & 5-attempt lockout
    if (SupabaseService.isInitialized) {
      final res = await SupabaseService.verifyStaffPin(pin: _enteredPin);
      if (!mounted) return;
      setState(() => _isVerifying = false);

      if (res.locked) {
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

        ref.read(currentStaffProvider.notifier).switchStaffDirect(staffMember);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text(staffMember.avatarIcon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text('Switched to ${staffMember.name} (${staffMember.roleDisplayName}) [Server Verified]'),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      } else {
        setState(() {
          _enteredPin = '';
          _errorMessage = res.remainingAttempts != null
              ? '${res.message} (${res.remainingAttempts} attempts remaining)'
              : res.message;
        });
        return;
      }
    }

    // Standalone Local Offline Fallback
    setState(() => _isVerifying = false);
    final success = ref.read(currentStaffProvider.notifier).switchStaffWithPin(_enteredPin);
    if (success) {
      final currentStaff = ref.read(currentStaffProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(currentStaff.avatarIcon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text('Switched to ${currentStaff.name} (${currentStaff.roleDisplayName})'),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      setState(() {
        _enteredPin = '';
        _errorMessage = 'Incorrect PIN! Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffList = ref.watch(staffListProvider);
    final currentStaff = ref.watch(currentStaffProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.badge_outlined, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Staff Fast-Switch & PIN Security',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Active: ${currentStaff.name} (${currentStaff.roleDisplayName})',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 520;
                  if (isNarrow) {
                    return Column(
                      children: [
                        _buildPinPad(isDark),
                        const Divider(height: 24),
                        _buildStaffList(staffList, currentStaff, isDark),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildStaffList(staffList, currentStaff, isDark),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 4,
                        child: _buildPinPad(isDark),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref.read(staffSessionProvider.notifier).logout();
                    },
                    icon: const Icon(Icons.lock_outline_rounded, color: Colors.redAccent, size: 16),
                    label: const Text(
                      'Lock Terminal / Sign Out',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaffList(List<StaffMember> staffList, StaffMember currentStaff, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Staff Team (Tap to switch):',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: staffList.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final staff = staffList[index];
              final isSelected = staff.id == currentStaff.id;

              return InkWell(
                onTap: () {
                  ref.read(currentStaffProvider.notifier).switchStaffDirect(staff);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Switched to ${staff.name} (${staff.roleDisplayName})'),
                      backgroundColor: const Color(0xFF16A34A),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(staff.avatarIcon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              staff.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              staff.roleDisplayName,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPinPad(bool isDark) {
    return Column(
      children: [
        const Text(
          'Enter 4-Digit Staff PIN:',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 12),

        // PIN Dots Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isFilled = index < _enteredPin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                border: Border.all(
                  color: isFilled ? AppColors.primary : Colors.grey.shade400,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),

        if (_errorMessage != null)
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
          )
        else
          const SizedBox(height: 16),

        // Keypad Grid
        Container(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Column(
            children: [
              _buildPinRow(['1', '2', '3'], isDark),
              const SizedBox(height: 8),
              _buildPinRow(['4', '5', '6'], isDark),
              const SizedBox(height: 8),
              _buildPinRow(['7', '8', '9'], isDark),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPinButton(
                    child: const Text('C', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    onTap: () => setState(() {
                      _enteredPin = '';
                      _errorMessage = null;
                    }),
                    isDark: isDark,
                  ),
                  _buildPinButton(
                    child: const Text('0', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    onTap: () => _onDigitPress('0'),
                    isDark: isDark,
                  ),
                  _buildPinButton(
                    child: const Icon(Icons.backspace_outlined, size: 18),
                    onTap: _onBackspace,
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinRow(List<String> digits, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits.map((d) {
        return _buildPinButton(
          child: Text(d, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          onTap: () => _onDigitPress(d),
          isDark: isDark,
        );
      }).toList(),
    );
  }

  Widget _buildPinButton({
    required Widget child,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 58,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: child,
      ),
    );
  }
}
