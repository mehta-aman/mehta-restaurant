import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'models/models.dart';
import 'features/accounts/accounts_screen.dart';
import 'features/kitchen/kitchen_screen.dart';
import 'features/menu/menu_management_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/tables/tables_screen.dart';
import 'providers/restaurant_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MehtaRestaurantApp(),
    ),
  );
}

class MehtaRestaurantApp extends StatelessWidget {
  const MehtaRestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mehta Restaurant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
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

  final List<Widget> _screens = const [
    TablesScreen(),
    KitchenScreen(),
    MenuManagementScreen(),
    AccountsScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(kitchenTicketsProvider);
    final activeKotCount = tickets.where((t) => t.status != KotState.served).length;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      // Responsive Desktop (macOS M1) Navigation Rail Layout
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) => setState(() => _currentIndex = index),
              extended: true,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.restaurant, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'MEHTA',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
                    ),
                    const Text(
                      'RESTAURANT',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary, letterSpacing: 0.8),
                    ),
                  ],
                ),
              ),
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.table_restaurant_outlined),
                  selectedIcon: Icon(Icons.table_restaurant),
                  label: Text('Tables (10)'),
                ),
                NavigationRailDestination(
                  icon: Badge(
                    label: Text('$activeKotCount'),
                    isLabelVisible: activeKotCount > 0,
                    child: const Icon(Icons.soup_kitchen_outlined),
                  ),
                  selectedIcon: Badge(
                    label: Text('$activeKotCount'),
                    isLabelVisible: activeKotCount > 0,
                    child: const Icon(Icons.soup_kitchen),
                  ),
                  label: const Text('Kitchen (KDS)'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.restaurant_menu_outlined),
                  selectedIcon: Icon(Icons.restaurant_menu),
                  label: Text('Menu Editor'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: Text('Credit Ledger'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics),
                  label: Text('Sales Reports'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _screens[_currentIndex]),
          ],
        ),
      );
    }

    // Responsive Mobile (iPhone & Android Phones) Bottom Navigation
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.table_restaurant_outlined),
            selectedIcon: Icon(Icons.table_restaurant),
            label: 'Tables',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('$activeKotCount'),
              isLabelVisible: activeKotCount > 0,
              child: const Icon(Icons.soup_kitchen_outlined),
            ),
            selectedIcon: Badge(
              label: Text('$activeKotCount'),
              isLabelVisible: activeKotCount > 0,
              child: const Icon(Icons.soup_kitchen),
            ),
            label: 'Kitchen',
          ),
          const NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Menu',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Credit',
          ),
          const NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Reports',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
