import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';
import '../tables/table_qr_dialog.dart';
import '../tables/add_edit_table_dialog.dart';
import '../tables/delete_table_dialog.dart';
import '../menu/digital_menu_screen.dart';
import '../../services/kitchen_audio_service.dart';
import '../../services/supabase_service.dart';
import '../../services/supabase_schema_source.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _taglineController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _gstinController;
  late TextEditingController _taxRateController;
  late TextEditingController _serviceChargeController;
  late TextEditingController _prefixController;
  late TextEditingController _upiIdController;
  late TextEditingController _upiNameController;
  late TextEditingController _receiptFooterController;
  late TextEditingController _supabaseUrlController;
  late TextEditingController _supabaseKeyController;
  final TextEditingController _tableSearchController = TextEditingController();

  late int _selectedPaperWidth;
  late bool _autoPrintReceipt;

  String _tableSearchQuery = '';
  String _tableFilterSection = 'All';

  bool _isKeyObscured = true;
  bool _isConnecting = false;
  bool _isSyncing = false;
  String? _connectionFeedback;
  bool? _lastConnectionSuccess;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _nameController = TextEditingController(text: settings.restaurantName);
    _taglineController = TextEditingController(text: settings.tagline);
    _addressController = TextEditingController(text: settings.address);
    _phoneController = TextEditingController(text: settings.phone);
    _emailController = TextEditingController(text: settings.email);
    _gstinController = TextEditingController(text: settings.gstin);
    _taxRateController = TextEditingController(text: settings.taxRate.toString());
    _serviceChargeController = TextEditingController(text: settings.serviceChargeRate.toString());
    _prefixController = TextEditingController(text: settings.invoicePrefix);
    _upiIdController = TextEditingController(text: settings.upiId);
    _upiNameController = TextEditingController(text: settings.upiPayeeName);
    _receiptFooterController = TextEditingController(text: settings.receiptFooterNote);
    _selectedPaperWidth = settings.thermalPaperWidth;
    _autoPrintReceipt = settings.autoPrintReceipt;
    _supabaseUrlController = TextEditingController(text: SupabaseService.supabaseUrl);
    _supabaseKeyController = TextEditingController(text: SupabaseService.supabaseAnonKey);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _gstinController.dispose();
    _taxRateController.dispose();
    _serviceChargeController.dispose();
    _prefixController.dispose();
    _upiIdController.dispose();
    _upiNameController.dispose();
    _receiptFooterController.dispose();
    _supabaseUrlController.dispose();
    _supabaseKeyController.dispose();
    _tableSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RestaurantSettings>(settingsProvider, (prev, next) {
      if (next != prev) {
        if (_nameController.text != next.restaurantName) _nameController.text = next.restaurantName;
        if (_taglineController.text != next.tagline) _taglineController.text = next.tagline;
        if (_addressController.text != next.address) _addressController.text = next.address;
        if (_phoneController.text != next.phone) _phoneController.text = next.phone;
        if (_emailController.text != next.email) _emailController.text = next.email;
        if (_gstinController.text != next.gstin) _gstinController.text = next.gstin;
        if (_taxRateController.text != next.taxRate.toString()) _taxRateController.text = next.taxRate.toString();
        if (_serviceChargeController.text != next.serviceChargeRate.toString()) _serviceChargeController.text = next.serviceChargeRate.toString();
        if (_prefixController.text != next.invoicePrefix) _prefixController.text = next.invoicePrefix;
        if (_upiIdController.text != next.upiId) _upiIdController.text = next.upiId;
        if (_upiNameController.text != next.upiPayeeName) _upiNameController.text = next.upiPayeeName;
        if (_receiptFooterController.text != next.receiptFooterNote) _receiptFooterController.text = next.receiptFooterNote;
        setState(() {
          _selectedPaperWidth = next.thermalPaperWidth;
          _autoPrintReceipt = next.autoPrintReceipt;
        });
      }
    });

    final settings = ref.watch(settingsProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant & Billing Settings'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 14 : 24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 0. APPEARANCE & THEME SECTION (Joyful Dark/Light Toggle)
                _buildThemeSelector(context, ref),
                const SizedBox(height: 18),

                // 0.5. CLOUD DATABASE (SUPABASE) SECTION
                _buildSupabaseCard(context, ref),
                const SizedBox(height: 18),

                // 1. GST & TAXATION SECTION (Mandatory Dynamic Toggle)
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 14 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Goods & Services Tax (GST)',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    settings.gstEnabled
                                        ? 'GST is currently ACTIVE on all bills and receipts'
                                        : 'Running in Non-GST / Composition mode (No tax added to bills)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: settings.gstEnabled ? AppColors.statusAvailable : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Switch(
                              value: settings.gstEnabled,
                              activeThumbColor: AppColors.primary,
                              onChanged: (val) {
                                ref.read(settingsProvider.notifier).toggleGst(val);
                              },
                            ),
                          ],
                        ),
                        if (settings.gstEnabled) ...[
                          const Divider(height: 24),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 450;
                              if (isNarrow) {
                                return Column(
                                  children: [
                                    TextField(
                                      controller: _gstinController,
                                      decoration: const InputDecoration(
                                        labelText: 'GSTIN Number (e.g. 08AAAAA0000A1Z5)',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _taxRateController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'GST Rate %',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        suffixText: '%',
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _gstinController,
                                      decoration: const InputDecoration(
                                        labelText: 'GSTIN Number (e.g. 08AAAAA0000A1Z5)',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 1,
                                    child: TextField(
                                      controller: _taxRateController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'GST Rate %',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        suffixText: '%',
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. RESTAURANT PROFILE
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 14 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Restaurant Identity',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Restaurant Display Name',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _taglineController,
                          decoration: const InputDecoration(
                            labelText: 'Restaurant Tagline / Slogan',
                            helperText: 'e.g. Pure Veg Restaurant & Sweets',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Address (printed on thermal receipt)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Contact Phone Number',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Contact Email (Optional)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2.5. UPI DIGITAL PAYMENTS CONFIGURATION (Dynamic QR Code)
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 14 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.qr_code_2, color: Colors.indigo, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'UPI Payments & Dynamic QR Code',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Customer scans exact bill amount pre-filled in GPay / PhonePe / Paytm',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _upiIdController,
                          decoration: const InputDecoration(
                            labelText: 'Restaurant UPI VPA / ID',
                            helperText: 'e.g. mehtarestaurant@okhdfcbank or 9876543210@paytm',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.alternate_email, size: 20),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _upiNameController,
                          decoration: const InputDecoration(
                            labelText: 'Payee Display Name',
                            helperText: 'Name shown on customer payment screen',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.storefront_outlined, size: 20),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2.7. DIGITAL MENU & TABLE QR STANDEES
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 14 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.table_restaurant_outlined, color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Table QR Standees & Digital Menu',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Printable tent cards for all active dining tables with QR code',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.phone_iphone, size: 18),
                              label: const Text('Preview Guest Digital Menu'),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const DigitalMenuScreen(tableNumber: 'T01'),
                                  ),
                                );
                              },
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.qr_code_2, size: 18),
                              label: const Text('Open QR Cards Generator & Print'),
                              onPressed: () {
                                final tables = ref.read(tablesProvider);
                                showDialog(
                                  context: context,
                                  builder: (_) => TableQrCardsDialog(tables: tables),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2.8. TABLE & FLOOR SECTION MANAGEMENT (CRUD)
                _buildTableManagementSection(context, ref),
                const SizedBox(height: 20),

                // 2.9. LIVE INVENTORY & STOCK TRACKING
                _buildInventoryTrackingCard(context, ref),
                const SizedBox(height: 20),

                // 3. INVOICING & PRINTER CONFIG
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 14 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Receipt & Invoice Configuration',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 450;
                            final prefixField = TextField(
                              controller: _prefixController,
                              decoration: const InputDecoration(
                                labelText: 'Invoice Number Prefix',
                                helperText: 'e.g. MR- results in MR-000001',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            );
                            final paperDropdown = DropdownButtonFormField<int>(
                              initialValue: _selectedPaperWidth,
                              decoration: const InputDecoration(
                                labelText: 'Thermal Paper Format',
                                helperText: 'Receipt printer roll width',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 80, child: Text('80mm / 3-inch (Standard)')),
                                DropdownMenuItem(value: 58, child: Text('58mm / 2-inch (Compact)')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedPaperWidth = val);
                              },
                            );

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isNarrow) ...[
                                  prefixField,
                                  const SizedBox(height: 14),
                                  paperDropdown,
                                ] else ...[
                                  Row(
                                    children: [
                                      Expanded(child: prefixField),
                                      const SizedBox(width: 16),
                                      Expanded(child: paperDropdown),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _receiptFooterController,
                                  decoration: const InputDecoration(
                                    labelText: 'Receipt Footer Note / Greeting',
                                    helperText: 'e.g. Thank you! Visit Again.',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Auto-Open Print Dialog upon Finalizing Bill', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  subtitle: const Text('Immediately triggers printer dialog when a bill is paid or settled', style: TextStyle(fontSize: 12)),
                                  value: _autoPrintReceipt,
                                  activeThumbColor: AppColors.primary,
                                  onChanged: (val) => setState(() => _autoPrintReceipt = val),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 3.5. KITCHEN AUDIO & BELL ALERTS (KDS)
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 14 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.notifications_active_outlined, color: Colors.amber, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Kitchen Display Audio & Bell Alerts (KDS)',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Audible bell alerts for new KOTs & warning chimes for orders delayed >15m',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: !ref.watch(kitchenAudioMutedProvider),
                              activeThumbColor: AppColors.primary,
                              onChanged: (enabled) {
                                ref.read(kitchenAudioMutedProvider.notifier).setMuted(!enabled);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'When enabled, your kitchen screen will play native chimes and trigger haptic feedback whenever a waiter sends a new order or when food preparation exceeds 15 minutes.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.notifications_active, size: 18),
                              label: const Text('Test Order Bell 🔔'),
                              onPressed: () async {
                                await KitchenAudioService.playNewOrderChime();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('🔔 Kitchen Bell Chime Played!'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                              },
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red),
                              label: const Text('Test Delay Alert ⚠️'),
                              onPressed: () async {
                                await KitchenAudioService.playDelayedOrderAlert();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('⚠️ Kitchen Delayed Alert Played!'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save Settings'),
                    onPressed: () {
                      final tax = double.tryParse(_taxRateController.text) ?? 5.0;
                      final serviceCharge = double.tryParse(_serviceChargeController.text) ?? 0.0;
                      ref.read(settingsProvider.notifier).updateSettings(
                            name: _nameController.text.trim(),
                            tagline: _taglineController.text.trim(),
                            address: _addressController.text.trim(),
                            phone: _phoneController.text.trim(),
                            email: _emailController.text.trim(),
                            gstin: _gstinController.text.trim(),
                            taxRate: tax,
                            serviceChargeRate: serviceCharge,
                            invoicePrefix: _prefixController.text.trim(),
                            upiId: _upiIdController.text.trim(),
                            upiPayeeName: _upiNameController.text.trim(),
                            receiptFooterNote: _receiptFooterController.text.trim(),
                            thermalPaperWidth: _selectedPaperWidth,
                            autoPrintReceipt: _autoPrintReceipt,
                          );

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Settings saved & synced to cloud!'),
                          backgroundColor: AppColors.statusAvailable,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.palette_outlined, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Appearance & Display Mode',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Choose your interface theme (Light or Dark)',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 450;
                if (isNarrow) {
                  return Column(
                    children: [
                      _buildThemeCard(
                        title: 'Light Mode',
                        subtitle: 'Clean & warm',
                        icon: Icons.light_mode,
                        iconColor: Colors.amber.shade700,
                        isSelected: currentTheme == ThemeMode.light,
                        onTap: () => ref.read(themeModeProvider.notifier).setTheme(ThemeMode.light),
                      ),
                      const SizedBox(height: 8),
                      _buildThemeCard(
                        title: 'Dark Mode',
                        subtitle: 'Midnight slate',
                        icon: Icons.dark_mode,
                        iconColor: const Color(0xFF818CF8),
                        isSelected: currentTheme == ThemeMode.dark,
                        onTap: () => ref.read(themeModeProvider.notifier).setTheme(ThemeMode.dark),
                      ),
                      const SizedBox(height: 8),
                      _buildThemeCard(
                        title: 'System',
                        subtitle: 'Auto device',
                        icon: Icons.brightness_auto,
                        iconColor: Colors.teal,
                        isSelected: currentTheme == ThemeMode.system,
                        onTap: () => ref.read(themeModeProvider.notifier).setTheme(ThemeMode.system),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: _buildThemeCard(
                        title: 'Light Mode',
                        subtitle: 'Clean & warm',
                        icon: Icons.light_mode,
                        iconColor: Colors.amber.shade700,
                        isSelected: currentTheme == ThemeMode.light,
                        onTap: () => ref.read(themeModeProvider.notifier).setTheme(ThemeMode.light),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildThemeCard(
                        title: 'Dark Mode',
                        subtitle: 'Midnight slate',
                        icon: Icons.dark_mode,
                        iconColor: const Color(0xFF818CF8),
                        isSelected: currentTheme == ThemeMode.dark,
                        onTap: () => ref.read(themeModeProvider.notifier).setTheme(ThemeMode.dark),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildThemeCard(
                        title: 'System',
                        subtitle: 'Auto device',
                        icon: Icons.brightness_auto,
                        iconColor: Colors.teal,
                        isSelected: currentTheme == ThemeMode.system,
                        onTap: () => ref.read(themeModeProvider.notifier).setTheme(ThemeMode.system),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
                color: isSelected ? AppColors.primary : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupabaseCard(BuildContext context, WidgetRef ref) {
    final isCloudConnected = ref.watch(supabaseConnectionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCloudConnected
              ? Colors.green.withValues(alpha: 0.4)
              : Colors.amber.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isCloudConnected
                          ? [const Color(0xFF059669), const Color(0xFF10B981)]
                          : [const Color(0xFF3B82F6), const Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isCloudConnected ? Icons.cloud_done : Icons.cloud_sync,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          const Text(
                            'Cloud Database (Supabase PostgreSQL)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCloudConnected
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isCloudConnected
                                    ? Colors.green.withValues(alpha: 0.4)
                                    : Colors.amber.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isCloudConnected ? Colors.green : Colors.amber.shade700,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isCloudConnected ? 'Cloud Active' : 'Local Offline Mode',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isCloudConnected ? Colors.green : Colors.amber.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isCloudConnected
                            ? 'All data (Menu, Customers, Khata Credit & Tables) is actively synced dynamically with Supabase.'
                            : 'Running locally in memory. Connect your Supabase project to enable dynamic multi-device sync and cloud backups.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),

            // URL input
            TextField(
              controller: _supabaseUrlController,
              decoration: const InputDecoration(
                labelText: 'Supabase Project URL',
                hintText: 'https://xxxxxxxxxxxx.supabase.co',
                helperText: 'Found in your Supabase Dashboard -> Project Settings -> API',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link, size: 20),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),

            // Anon Key input
            TextField(
              controller: _supabaseKeyController,
              obscureText: _isKeyObscured,
              decoration: InputDecoration(
                labelText: 'Supabase Anon Public API Key',
                hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                helperText: 'Anon public key with client-side RLS permissions',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.key, size: 20),
                isDense: true,
                suffixIcon: IconButton(
                  icon: Icon(_isKeyObscured ? Icons.visibility : Icons.visibility_off, size: 20),
                  onPressed: () => setState(() => _isKeyObscured = !_isKeyObscured),
                ),
              ),
            ),

            // Feedback Message Banner
            if (_connectionFeedback != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: (_lastConnectionSuccess == true ? Colors.green : Colors.red)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (_lastConnectionSuccess == true ? Colors.green : Colors.red)
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _lastConnectionSuccess == true ? Icons.check_circle : Icons.error_outline,
                      color: _lastConnectionSuccess == true ? Colors.green : Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _connectionFeedback!,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: _lastConnectionSuccess == true
                              ? (isDark ? Colors.green.shade300 : Colors.green.shade800)
                              : (isDark ? Colors.red.shade300 : Colors.red.shade800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Action Buttons
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: _isConnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cable, size: 18),
                  label: Text(_isConnecting ? 'Testing Connection...' : 'Test & Connect Database'),
                  onPressed: _isConnecting
                      ? null
                      : () async {
                          final url = _supabaseUrlController.text.trim();
                          final key = _supabaseKeyController.text.trim();

                          if (url.isEmpty || key.isEmpty) {
                            setState(() {
                              _lastConnectionSuccess = false;
                              _connectionFeedback = 'Please enter both the Supabase URL and Anon Key.';
                            });
                            return;
                          }

                          setState(() {
                            _isConnecting = true;
                            _connectionFeedback = null;
                          });

                          final result = await SupabaseService.testConnection(url: url, anonKey: key);

                          if (result.success) {
                            final saved = await SupabaseService.saveAndInitialize(url: url, anonKey: key);
                            if (saved) {
                              ref.read(supabaseConnectionProvider.notifier).setConnected(true);
                              await syncAllCloudData(ref);
                            }
                            setState(() {
                              _isConnecting = false;
                              _lastConnectionSuccess = true;
                              _connectionFeedback = result.message;
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🎉 Connected to Supabase! Cloud data synced.'),
                                  backgroundColor: AppColors.statusAvailable,
                                ),
                              );
                            }
                          } else {
                            setState(() {
                              _isConnecting = false;
                              _lastConnectionSuccess = false;
                              _connectionFeedback = result.message;
                            });
                          }
                        },
                ),
                if (isCloudConnected) ...[
                  OutlinedButton.icon(
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, size: 18),
                    label: Text(_isSyncing ? 'Syncing...' : 'Sync Cloud Data Now'),
                    onPressed: _isSyncing
                        ? null
                        : () async {
                            setState(() => _isSyncing = true);
                            await syncAllCloudData(ref);
                            setState(() => _isSyncing = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Data successfully synced from Supabase cloud!'),
                                  backgroundColor: AppColors.statusAvailable,
                                ),
                              );
                            }
                          },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.link_off, size: 18, color: Colors.red),
                    label: const Text('Disconnect', style: TextStyle(color: Colors.red)),
                    onPressed: () async {
                      await SupabaseService.disconnect();
                      ref.read(supabaseConnectionProvider.notifier).setConnected(false);
                      setState(() {
                        _connectionFeedback = 'Disconnected. App returned to local offline mode.';
                        _lastConnectionSuccess = null;
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Disconnected from Supabase.')),
                        );
                      }
                    },
                  ),
                ],
                TextButton.icon(
                  icon: const Icon(Icons.help_outline, size: 18),
                  label: const Text('Setup Guide & SQL Schema'),
                  onPressed: () => _showSupabaseGuideDialog(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSupabaseGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Row(
            children: [
              Icon(Icons.cloud_done_outlined, color: Colors.indigo),
              SizedBox(width: 10),
              Expanded(
                child: Text('Supabase Setup Guide (4 Steps)', overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Follow these steps to connect your Mehta Restaurant system to your cloud database in under 2 minutes:',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  _buildGuideStep(
                    stepNumber: '1',
                    title: 'Create a free project on Supabase',
                    description: 'Visit supabase.com, sign up or log in, and click "New Project". Set your database password and choose your region (e.g., Mumbai, India).',
                  ),
                  const SizedBox(height: 12),
                  _buildGuideStep(
                    stepNumber: '2',
                    title: 'Open the SQL Editor',
                    description: 'In your Supabase project dashboard, click the "SQL Editor" icon in the left-hand navigation bar, then click "New query".',
                  ),
                  const SizedBox(height: 12),
                  _buildGuideStep(
                    stepNumber: '3',
                    title: 'Paste and Run the Database Schema',
                    description: 'Click the button below to copy the complete Mehta Restaurant database schema (tables, authentic menu items, customer accounts & security rules), paste it into the SQL editor, and click "Run".',
                    actionWidget: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy Complete SQL Script to Clipboard'),
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: kSupabaseSchemaSql));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('📋 SQL Schema copied to clipboard! Paste into Supabase SQL Editor.'),
                              backgroundColor: AppColors.statusAvailable,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildGuideStep(
                    stepNumber: '4',
                    title: 'Copy your API Credentials',
                    description: 'Navigate to Project Settings -> API in your Supabase dashboard. Copy the "Project URL" and the "anon public" key, paste them into the settings inputs above, and click "Test & Connect Database"!',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Got it!'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuideStep({
    required String stepNumber,
    required String title,
    required String description,
    Widget? actionWidget,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Colors.indigo.withValues(alpha: 0.15),
          child: Text(
            stepNumber,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.35),
              ),
              ?actionWidget,
            ],
          ),
        ),
      ],
    );
  }

  Color _getSectionColor(String section) {
    final s = section.toLowerCase();
    if (s.contains('outdoor') || s.contains('lawn') || s.contains('garden')) {
      return const Color(0xFF15803D);
    }
    if (s.contains('rooftop') || s.contains('terrace') || s.contains('sky')) {
      return const Color(0xFF7C3AED);
    }
    if (s.contains('banquet') || s.contains('hall') || s.contains('first')) {
      return const Color(0xFFD97706);
    }
    return const Color(0xFF0284C7); // Indoor AC
  }

  Widget _buildTableManagementSection(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final tables = ref.watch(tablesProvider);
    final orders = ref.watch(ordersProvider);

    // Compute live metrics
    final totalTables = tables.length;
    final totalSeats = tables.fold<int>(0, (sum, t) => sum + t.capacity);
    final indoorCount = tables.where((t) => t.section.toLowerCase().contains('indoor')).length;
    final outdoorCount = tables.where((t) =>
        t.section.toLowerCase().contains('outdoor') ||
        t.section.toLowerCase().contains('lawn') ||
        t.section.toLowerCase().contains('garden')).length;
    final rooftopCount = tables.where((t) =>
        t.section.toLowerCase().contains('rooftop') ||
        t.section.toLowerCase().contains('terrace')).length;
    final activeOccupiedCount = tables.where((t) => t.status != TableState.available).length;
    final disabledCount = tables.where((t) => !t.isEnabled).length;

    final allSections = ['All', ...{...tables.map((t) => t.section)}];

    final filteredTables = tables.where((t) {
      final matchesSection = _tableFilterSection == 'All' || t.section == _tableFilterSection;
      final matchesSearch = _tableSearchQuery.isEmpty ||
          t.tableNumber.toLowerCase().contains(_tableSearchQuery.toLowerCase()) ||
          t.name.toLowerCase().contains(_tableSearchQuery.toLowerCase()) ||
          t.section.toLowerCase().contains(_tableSearchQuery.toLowerCase());
      return matchesSection && matchesSearch;
    }).toList();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Title, Description & + Add Table Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.table_restaurant, color: Color(0xFF0284C7), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Table & Floor Management (CRUD)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Create, rename, relocate indoor/outdoor/rooftop, and set seating capacities',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 8 : 12,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    isMobile ? 'Add' : 'Add Table',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const AddEditTableDialog(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Live Metric Badges Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMetricPill(
                    icon: Icons.grid_view,
                    label: 'Tables',
                    value: '$totalTables Active',
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricPill(
                    icon: Icons.people_outline,
                    label: 'Capacity',
                    value: '$totalSeats Seats',
                    color: const Color(0xFF059669),
                  ),
                  const SizedBox(width: 8),
                  _buildMetricPill(
                    icon: Icons.location_city_outlined,
                    label: 'Zones',
                    value: '$indoorCount In • $outdoorCount Out${rooftopCount > 0 ? " • $rooftopCount Roof" : ""}',
                    color: const Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 8),
                  _buildMetricPill(
                    icon: Icons.check_circle_outline,
                    label: 'Status',
                    value: '${totalTables - activeOccupiedCount - disabledCount} Free • $activeOccupiedCount Dining',
                    color: activeOccupiedCount > 0 ? AppColors.statusOccupied : AppColors.statusAvailable,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search and Floor Section Filters
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tableSearchController,
                    decoration: InputDecoration(
                      hintText: 'Search by table number, name, or zone...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _tableSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _tableSearchController.clear();
                                setState(() => _tableSearchQuery = '');
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _tableSearchQuery = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Floor / Section Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: allSections.map((sec) {
                  final isSelected = _tableFilterSection == sec;
                  final count = sec == 'All'
                      ? tables.length
                      : tables.where((t) => t.section == sec).length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Text('$sec ($count)'),
                      onSelected: (val) {
                        if (val) setState(() => _tableFilterSection = sec);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Tables List
            if (filteredTables.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        'No tables match "${_tableSearchQuery.isNotEmpty ? _tableSearchQuery : _tableFilterSection}"',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try clearing the search or add a new table.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Table Now'),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => const AddEditTableDialog(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredTables.length,
                separatorBuilder: (context, _) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final table = filteredTables[index];
                  final order = orders[table.tableNumber];
                  final secColor = _getSectionColor(table.section);

                  return LayoutBuilder(
                    builder: (context, itemConstraints) {
                      final isCompact = itemConstraints.maxWidth < 460;
                      if (isCompact) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Table Number Badge
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: !table.isEnabled
                                          ? Colors.grey.shade300
                                          : (table.status != TableState.available
                                              ? AppColors.primary
                                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: !table.isEnabled
                                            ? Colors.grey.shade400
                                            : (table.status != TableState.available
                                                ? AppColors.primary
                                                : (isDark ? AppColors.darkBorder : AppColors.border)),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      table.tableNumber,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: !table.isEnabled
                                            ? Colors.grey.shade700
                                            : (table.status != TableState.available
                                                ? Colors.white
                                                : (isDark ? Colors.white : AppColors.textPrimary)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          table.displayName,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: !table.isEnabled ? Colors.grey.shade500 : null,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 5,
                                          runSpacing: 4,
                                          children: [
                                            // Floor / Zone chip
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: secColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: secColor.withValues(alpha: 0.3)),
                                              ),
                                              child: Text(
                                                table.section,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: secColor,
                                                ),
                                              ),
                                            ),
                                            // Capacity badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.people_alt_outlined, size: 11, color: isDark ? Colors.white70 : Colors.black87),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    '${table.capacity} Seats',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: isDark ? Colors.white70 : Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Status badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: !table.isEnabled
                                                    ? Colors.grey.shade200
                                                    : (table.status == TableState.available
                                                        ? AppColors.statusAvailableBg
                                                        : (table.status == TableState.occupied
                                                            ? AppColors.statusOccupiedBg
                                                            : AppColors.statusBillingBg)),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                !table.isEnabled
                                                    ? 'OFF'
                                                    : (table.status == TableState.available
                                                        ? 'AVAILABLE'
                                                        : (table.status == TableState.occupied ? 'OCCUPIED' : 'BILL PENDING')),
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: !table.isEnabled
                                                      ? Colors.grey.shade700
                                                      : (table.status == TableState.available
                                                          ? AppColors.statusAvailable
                                                          : (table.status == TableState.occupied
                                                              ? AppColors.statusOccupied
                                                              : AppColors.statusBilling)),
                                                ),
                                              ),
                                            ),
                                            if (order != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '₹${order.grandTotal.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.amber.shade900,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: table.isEnabled ? 'Turn Table OFF' : 'Turn Table ON',
                                    child: Transform.scale(
                                      scale: 0.8,
                                      child: Switch(
                                        value: table.isEnabled,
                                        activeThumbColor: AppColors.primary,
                                        onChanged: (val) {
                                          ref.read(tablesProvider.notifier).toggleTableEnabled(table.tableNumber);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(Icons.edit_outlined, size: 15),
                                    label: const Text('Edit Table', style: TextStyle(fontSize: 12)),
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (_) => AddEditTableDialog(table: table),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor: Colors.red,
                                    ),
                                    icon: const Icon(Icons.delete_outline, size: 15, color: Colors.red),
                                    label: const Text('Delete', style: TextStyle(fontSize: 12)),
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (_) => DeleteTableDialog(table: table),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }
                      // Wide / Desktop layout
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Table Number Badge
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: !table.isEnabled
                                    ? Colors.grey.shade300
                                    : (table.status != TableState.available
                                        ? AppColors.primary
                                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: !table.isEnabled
                                      ? Colors.grey.shade400
                                      : (table.status != TableState.available
                                          ? AppColors.primary
                                          : (isDark ? AppColors.darkBorder : AppColors.border)),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                table.tableNumber,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: !table.isEnabled
                                      ? Colors.grey.shade700
                                      : (table.status != TableState.available
                                          ? Colors.white
                                          : (isDark ? Colors.white : AppColors.textPrimary)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Table Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    table.displayName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: !table.isEnabled ? Colors.grey.shade500 : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: secColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: secColor.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          table.section,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: secColor,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.people_alt_outlined, size: 11, color: isDark ? Colors.white70 : Colors.black87),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${table.capacity} Seats',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white70 : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: !table.isEnabled
                                              ? Colors.grey.shade200
                                              : (table.status == TableState.available
                                                  ? AppColors.statusAvailableBg
                                                  : (table.status == TableState.occupied
                                                      ? AppColors.statusOccupiedBg
                                                      : AppColors.statusBillingBg)),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          !table.isEnabled
                                              ? 'OFF'
                                              : (table.status == TableState.available
                                                  ? 'AVAILABLE'
                                                  : (table.status == TableState.occupied ? 'OCCUPIED' : 'BILL PENDING')),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: !table.isEnabled
                                                ? Colors.grey.shade700
                                                : (table.status == TableState.available
                                                    ? AppColors.statusAvailable
                                                    : (table.status == TableState.occupied
                                                        ? AppColors.statusOccupied
                                                        : AppColors.statusBilling)),
                                          ),
                                        ),
                                      ),
                                      if (order != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '₹${order.grandTotal.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Action Controls
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: table.isEnabled ? 'Turn Table OFF' : 'Turn Table ON',
                                  child: Transform.scale(
                                    scale: 0.8,
                                    child: Switch(
                                      value: table.isEnabled,
                                      activeThumbColor: AppColors.primary,
                                      onChanged: (val) {
                                        ref.read(tablesProvider.notifier).toggleTableEnabled(table.tableNumber);
                                      },
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  tooltip: 'Edit Table Details',
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (_) => AddEditTableDialog(table: table),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                  tooltip: 'Delete Table',
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (_) => DeleteTableDialog(table: table),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
              Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryTrackingCard(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isTracking = settings.inventoryTrackingEnabled;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isTracking
                        ? Colors.teal.withValues(alpha: 0.15)
                        : (isDark ? Colors.blueGrey.shade800 : Colors.blueGrey.shade100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: isTracking ? Colors.teal : (isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Inventory & Stock Tracking',
                            style: TextStyle(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isTracking
                                  ? (isDark ? const Color(0xFF064E3B) : Colors.green.shade100)
                                  : (isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isTracking ? 'Active' : 'Disabled (Default)',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isTracking
                                    ? (isDark ? const Color(0xFF34D399) : Colors.green.shade800)
                                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isTracking
                            ? 'Physical stock decrements upon billing. Low-stock alerts and "Sold Out" blocks are active.'
                            : 'Stock tracking is currently OFF. All items are freely available for billing without quantity limits or out-of-stock blocks.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: isTracking,
                  activeThumbColor: Colors.teal,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).toggleInventoryTracking(val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          val
                              ? '🟢 Inventory & Live Stock Tracking enabled!'
                              : '⚪ Stock tracking disabled. All dishes are available unconditionally.',
                        ),
                        backgroundColor: val ? Colors.teal : Colors.blueGrey,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_done_outlined,
                        size: 16,
                        color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Backend Database Ready & Connected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.blue.shade300 : Colors.blue.shade800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your stock quantities, reorder thresholds, and packaged items (Bikaji snacks, mineral water, cold drinks) remain safely preserved in the database (menu_items table). When you turn this toggle ON in the future, live stock decrements, low-stock alerts, and restocking immediately take effect without losing any data.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

