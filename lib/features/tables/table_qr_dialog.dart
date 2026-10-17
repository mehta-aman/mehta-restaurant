import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';
import '../menu/digital_menu_screen.dart';

class TableQrCardsDialog extends ConsumerStatefulWidget {
  final List<RestaurantTable> tables;
  final String? initialTable;

  const TableQrCardsDialog({
    super.key,
    required this.tables,
    this.initialTable,
  });

  @override
  ConsumerState<TableQrCardsDialog> createState() => _TableQrCardsDialogState();
}

class _TableQrCardsDialogState extends ConsumerState<TableQrCardsDialog> {
  late String _selectedTable;
  final String _baseHost = 'http://172.20.10.5:8080';

  @override
  void initState() {
    super.initState();
    _selectedTable = widget.initialTable ??
        (widget.tables.isNotEmpty ? widget.tables.first.tableNumber : 'T01');
  }

  String _getTableUrl(String tableNumber) {
    return '$_baseHost/#/menu?table=$tableNumber';
  }

  Future<void> _printTableCards({required bool printAll}) async {
    final settings = ref.read(settingsProvider);
    final pdf = pw.Document();

    final tablesToPrint = printAll
        ? widget.tables
        : widget.tables.where((t) => t.tableNumber == _selectedTable).toList();

    // Standard A4: 210 x 297 mm, 2 table cards per page
    for (int i = 0; i < tablesToPrint.length; i += 2) {
      final t1 = tablesToPrint[i];
      final t2 = (i + 1 < tablesToPrint.length) ? tablesToPrint[i + 1] : null;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              children: [
                _buildPdfCard(t1, settings),
                if (t2 != null) ...[
                  pw.SizedBox(height: 16),
                  pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                  pw.SizedBox(height: 16),
                  _buildPdfCard(t2, settings),
                ],
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: printAll ? 'Mehta_Restaurant_Table_QR_Cards' : 'Table_${_selectedTable}_QR_Card',
    );
  }

  pw.Widget _buildPdfCard(RestaurantTable table, RestaurantSettings settings) {
    final url = _getTableUrl(table.tableNumber);
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  settings.restaurantName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange900,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  settings.tagline.isNotEmpty ? settings.tagline : 'Contactless Digital Menu & Ordering',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.orange100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.orange400),
                  ),
                  child: pw.Text(
                    'TABLE ${table.tableNumber} ${table.name.isNotEmpty && table.name != table.tableNumber ? "• ${table.name.toUpperCase()} " : ""}• ${table.section.toUpperCase()} • ${table.capacity} SEATER',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.orange900,
                    ),
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  '1. Open Camera or Google Lens on your phone',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Text(
                  '2. Scan this QR Code to browse our live digital menu',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Text(
                  '3. Explore fresh dishes, packaged snacks & drinks',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Free Wi-Fi available • Mehta Restaurant',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Column(
              children: [
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: url,
                  width: 120,
                  height: 120,
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'SCAN FOR MENU',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final currentTable = widget.tables.firstWhere(
      (t) => t.tableNumber == _selectedTable,
      orElse: () => widget.tables.first,
    );
    final targetUrl = _getTableUrl(_selectedTable);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        child: const Icon(Icons.qr_code_2, color: AppColors.primary, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Table QR Code & Digital Menu',
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Generate standees & contactless digital cards for ${widget.tables.length} tables',
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
              const Divider(height: 24),

              // Table Selector Chips
              const Text(
                'Select Table to Preview / Print:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.tables.map((t) {
                    final isSelected = t.tableNumber == _selectedTable;
                    final label = t.name.isNotEmpty && t.name != t.tableNumber
                        ? '${t.tableNumber} • ${t.name}'
                        : t.tableNumber;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: isSelected,
                        label: Text(label),
                        onSelected: (_) => setState(() => _selectedTable = t.tableNumber),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),

              // Visual Table Standee Preview Card
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 440),
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                          : [Colors.white, const Color(0xFFFFF7ED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFFED7AA),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Card Top
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.restaurant, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            settings.restaurantName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        settings.tagline.isNotEmpty ? settings.tagline : 'Traditional Flavors • Pure Quality',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Table Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'TABLE ${currentTable.tableNumber}${currentTable.name.isNotEmpty && currentTable.name != currentTable.tableNumber ? " (${currentTable.name})" : ""} • ${currentTable.section.toUpperCase()} • ${currentTable.capacity} SEATER',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // QR Code Container
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            QrImageView(
                              data: targetUrl,
                              version: QrVersions.auto,
                              size: 160,
                              backgroundColor: Colors.white,
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'SCAN WITH PHONE CAMERA',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Browse 30+ Menu Items, Bikaji Snacks & Drinks',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.wifi, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Complimentary Wi-Fi Available',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.phone_iphone, size: 18),
                    label: const Text('Preview Guest Menu'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DigitalMenuScreen(tableNumber: _selectedTable),
                        ),
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.print, size: 18),
                    label: Text('Print $_selectedTable Card'),
                    onPressed: () => _printTableCards(printAll: false),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Print All 10 (PDF)'),
                    onPressed: () => _printTableCards(printAll: true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
