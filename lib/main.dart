import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'models/models.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/tables/tables_screen.dart';
import 'features/kitchen/kitchen_screen.dart';
import 'features/accounts/accounts_screen.dart';
import 'features/menu/menu_management_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/staff/staff_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/bills/bills_screen.dart';
import 'features/staff/staff_switch_dialog.dart';
import 'features/ai_assistant/ai_floating_button.dart';
import 'features/ai_assistant/ai_assistant_sheet.dart';
import 'providers/restaurant_provider.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initFromPreferences();
  runApp(
    const ProviderScope(
      child: MehtaRestaurantApp(),
    ),
  );
}

class MehtaRestaurantApp extends ConsumerWidget {
  const MehtaRestaurantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: settings.restaurantName.isNotEmpty ? settings.restaurantName : 'Mehta Restaurant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (SupabaseService.isInitialized) {
        ref.read(supabaseConnectionProvider.notifier).setConnected(true);
        await syncAllCloudData(ref);
        SupabaseService.subscribeToRealtimeChanges(() {
          if (mounted) {
            syncAllCloudData(ref);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    SupabaseService.unsubscribeRealtime();
    super.dispose();
  }

  void _onNavigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(kitchenTicketsProvider);
    final activeKotCount = tickets.where((t) => t.status != KotState.served).length;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1050;
    final isTablet = screenWidth >= 650 && screenWidth < 1050;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentStaff = ref.watch(currentStaffProvider);
    final isCloudConnected = ref.watch(supabaseConnectionProvider);

    final screens = [
      DashboardScreen(onNavigateToTab: _onNavigateToTab),
      const TablesScreen(),
      const KitchenScreen(),
      const BillsScreen(),
      const AccountsScreen(),
      const MenuManagementScreen(),
      const ReportsScreen(),
      const StaffScreen(),
      const SettingsScreen(),
    ];

    final safeIndex = (_currentIndex >= 0 && _currentIndex < screens.length) ? _currentIndex : 0;

    final settings = ref.watch(settingsProvider);

    // Desktop and Tablet: Persistent Dark Charcoal Sidebar Navigation Shell
    if (isDesktop || isTablet) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
        floatingActionButton: const AiFloatingButton(),
        body: Row(
          children: [
            // Dark Sidebar Navigation matching reference
            _buildDarkSidebar(
              isDesktop: isDesktop,
              currentIndex: safeIndex,
              activeKotCount: activeKotCount,
              currentStaff: currentStaff,
              isCloudConnected: isCloudConnected,
              isDark: isDark,
              settings: settings,
            ),
            // Main Content Area with Top Header
            Expanded(
              child: Column(
                children: [
                  _buildTopHeaderBar(
                    isDesktop: isDesktop,
                    currentStaff: currentStaff,
                    isDark: isDark,
                  ),
                  Expanded(child: screens[safeIndex]),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Responsive Mobile (iPhone) Bottom Navigation Shell matching reference
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      floatingActionButton: const AiFloatingButton(),
      body: screens[safeIndex],
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: safeIndex <= 2 ? safeIndex : 3,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        indicatorColor: AppColors.primaryLight,
        onDestinationSelected: (index) {
          if (index < 3) {
            setState(() => _currentIndex = index);
          } else {
            _showMobileMoreBottomSheet(context, isDark);
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined, size: 22),
            selectedIcon: Icon(Icons.home, color: AppColors.primary, size: 22),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.table_restaurant_outlined, size: 22),
            selectedIcon: Icon(Icons.table_restaurant, color: AppColors.primary, size: 22),
            label: 'Tables',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('$activeKotCount'),
              isLabelVisible: activeKotCount > 0,
              child: const Icon(Icons.receipt_long_outlined, size: 22),
            ),
            selectedIcon: Badge(
              label: Text('$activeKotCount'),
              isLabelVisible: activeKotCount > 0,
              child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 22),
            ),
            label: 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded, size: 22),
            selectedIcon: Icon(Icons.more_horiz_rounded, color: AppColors.primary, size: 22),
            label: 'More',
          ),
        ],
      ),
    );
  }

  // --- DARK CHARCOAL DESKTOP SIDEBAR ---
  Widget _buildDarkSidebar({
    required bool isDesktop,
    required int currentIndex,
    required int activeKotCount,
    required StaffMember currentStaff,
    required bool isCloudConnected,
    required bool isDark,
    required RestaurantSettings settings,
  }) {
    final navItems = [
      (index: 0, title: 'Home', icon: Icons.grid_view_rounded, badge: 0),
      (index: 1, title: 'Tables', icon: Icons.table_restaurant_rounded, badge: 0),
      (index: 2, title: 'Orders', icon: Icons.soup_kitchen_rounded, badge: activeKotCount),
      (index: 3, title: 'Bills', icon: Icons.receipt_long_rounded, badge: 0),
      (index: 4, title: 'Customers', icon: Icons.people_alt_rounded, badge: 0),
      (index: 5, title: 'Menu', icon: Icons.restaurant_menu_rounded, badge: 0),
      (index: 6, title: 'Reports', icon: Icons.bar_chart_rounded, badge: 0),
      (index: 7, title: 'Staff', icon: Icons.badge_rounded, badge: 0),
      (index: 8, title: 'Settings', icon: Icons.settings_rounded, badge: 0),
    ];

    return Container(
      width: isDesktop ? 228 : 74,
      decoration: const BoxDecoration(
        color: AppColors.navBg,
        border: Border(
          right: BorderSide(color: Color(0xFF2C2D31), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Brand Logo Header
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 18 : 12,
              vertical: 22,
            ),
            child: Row(
              mainAxisAlignment: isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.restaurant, color: Colors.white, size: 20),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settings.restaurantName.isNotEmpty ? settings.restaurantName : 'Mehta Restaurant',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          settings.tagline.isNotEmpty ? settings.tagline : 'Good Food • Happy People',
                          style: const TextStyle(
                            color: Color(0xFF8E9096),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Nav Items List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 12 : 8),
              itemCount: navItems.length,
              itemBuilder: (context, i) {
                final item = navItems[i];
                final isActive = currentIndex == item.index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = item.index),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 44,
                      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 14 : 0),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.navActiveBg : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.icon,
                            size: 20,
                            color: isActive ? Colors.white : const Color(0xFF9EA0A5),
                          ),
                          if (isDesktop) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  color: isActive ? Colors.white : const Color(0xFFB5B7BC),
                                  fontSize: 13.5,
                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (item.badge > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActive ? Colors.white : AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${item.badge}',
                                  style: TextStyle(
                                    color: isActive ? AppColors.primary : Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Section: Cloud Status & Staff Profile
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (isDesktop) ...[
                  // Cloud Status Pill
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171819),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCloudConnected
                            ? const Color(0xFF2E7D32).withValues(alpha: 0.4)
                            : const Color(0xFFE65100).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isCloudConnected ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isCloudConnected ? 'Cloud Active' : 'Local Mode',
                          style: TextStyle(
                            color: isCloudConnected ? const Color(0xFF81C784) : const Color(0xFFFFB74D),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Staff Switcher Card
                  InkWell(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => const StaffSwitchDialog(),
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171819),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                            child: Text(currentStaff.avatarIcon, style: const TextStyle(fontSize: 14)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentStaff.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  currentStaff.roleDisplayName,
                                  style: const TextStyle(
                                    color: Color(0xFF8E9096),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.unfold_more, size: 16, color: Color(0xFF8E9096)),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  IconButton(
                    icon: Text(currentStaff.avatarIcon, style: const TextStyle(fontSize: 18)),
                    tooltip: 'Switch Staff',
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const StaffSwitchDialog(),
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

  // --- TOP HEADER BAR IN MAIN WORKSPACE ---
  Widget _buildTopHeaderBar({
    required bool isDesktop,
    required StaffMember currentStaff,
    required bool isDark,
  }) {
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Spacer(),

          // AI Assistant Header Shortcut
          InkWell(
            onTap: () => AiAssistantSheet.show(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Ask AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Notification Bell
          IconButton(
            icon: const Badge(
              smallSize: 8,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.notifications_none_rounded, size: 21),
            ),
            tooltip: 'Notifications',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All systems active. Supabase Cloud live synchronized.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),

          const SizedBox(width: 6),

          // User Profile Badge matching reference: Avatar + Name + Role dropdown
          InkWell(
            onTap: () => showDialog(
              context: context,
              builder: (_) => const StaffSwitchDialog(),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(currentStaff.avatarIcon, style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentStaff.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        currentStaff.roleDisplayName,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Theme Toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
              color: isDark ? Colors.amber : const Color(0xFF475569),
            ),
            tooltip: 'Toggle Theme',
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          ),
        ],
      ),
    );
  }

  // --- MOBILE MORE BOTTOM SHEET ---
  void _showMobileMoreBottomSheet(BuildContext context, bool isDark) {
    final moreDestinations = [
      (index: 3, title: 'Bills & Invoices', icon: Icons.receipt_long_outlined),
      (index: 4, title: 'Customers & Khata', icon: Icons.people_alt_outlined),
      (index: 5, title: 'Menu Editor', icon: Icons.restaurant_menu_outlined),
      (index: 6, title: 'Sales Reports', icon: Icons.bar_chart_outlined),
      (index: 7, title: 'Staff Management', icon: Icons.badge_outlined),
      (index: 8, title: 'Settings', icon: Icons.settings_outlined),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ...moreDestinations.map((d) {
                  return ListTile(
                    leading: Icon(d.icon, color: AppColors.primary),
                    title: Text(
                      d.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _currentIndex = d.index);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
