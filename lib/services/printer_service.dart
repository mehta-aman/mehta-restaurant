import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';

class PrinterService {
  static Future<Uint8List> generateThermalReceipt({
    required Invoice invoice,
    required RestaurantSettings settings,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    final rollWidthMm = settings.thermalPaperWidth == 58 ? 54.0 : 72.0;
    final pageFormat = PdfPageFormat(
      rollWidthMm * PdfPageFormat.mm,
      double.infinity,
      marginAll: 4 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header
              pw.Text(
                settings.restaurantName.toUpperCase(),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                textAlign: pw.TextAlign.center,
              ),
              if (settings.tagline.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 1, bottom: 2),
                  child: pw.Text(
                    settings.tagline,
                    style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              if (settings.address.isNotEmpty)
                pw.Text(
                  settings.address,
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              if (settings.phone.isNotEmpty)
                pw.Text(
                  'Ph: ${settings.phone}',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              if (settings.email.isNotEmpty)
                pw.Text(
                  settings.email,
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              if (settings.gstEnabled && settings.gstin.isNotEmpty)
                pw.Text(
                  'GSTIN: ${settings.gstin}',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

              // Metadata
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bill: ${invoice.invoiceNumber}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Table: ${invoice.tableNumber}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(dateFormat.format(invoice.issuedAt), style: const pw.TextStyle(fontSize: 7)),
                  if (invoice.customerName != null)
                    pw.Text('Cust: ${invoice.customerName}', style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

              // Items Header
              pw.Row(
                children: [
                  pw.Expanded(flex: 5, child: pw.Text('Item', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 3, child: pw.Text('Amt (Rs.)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.SizedBox(height: 2),

              // Items List
              ...invoice.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 5, child: pw.Text(item.name, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Expanded(flex: 2, child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Expanded(flex: 3, child: pw.Text(item.totalPrice.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                    ],
                  ),
                );
              }),

              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Rs. ${invoice.subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              if (settings.gstEnabled && invoice.taxAmount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('GST (${settings.taxRate}%):', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Rs. ${invoice.taxAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('GRAND TOTAL:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Rs. ${invoice.grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),

              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

              // Payments breakdown
              if (invoice.cashPaid > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Cash Paid:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Rs. ${invoice.cashPaid.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              if (invoice.upiPaid > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('UPI Paid:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Rs. ${invoice.upiPaid.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              if (invoice.creditAmount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Pending on Credit:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rs. ${invoice.creditAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),

              // Split Bill Breakdown on Master Receipt
              if (invoice.isSplitBill) ...[
                pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
                pw.Text('SPLIT BILL BREAKDOWN', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                for (final split in invoice.splits!)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${split.label} (${split.paymentMode}):', style: const pw.TextStyle(fontSize: 7)),
                      pw.Text('Rs. ${split.amount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7)),
                    ],
                  ),
              ],

              // Dynamic UPI QR Code for instant scan & pay on receipt
              if (settings.upiId.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text('Scan to Pay via UPI', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: settings.generateUpiUri(
                      amount: invoice.grandTotal,
                      note: 'Bill ${invoice.invoiceNumber}',
                    ),
                    width: 68,
                    height: 68,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(settings.upiId, style: const pw.TextStyle(fontSize: 6.5)),
                pw.Text('GPay • PhonePe • Paytm • BHIM', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
              ],

              pw.SizedBox(height: 6),
              pw.Text(
                settings.receiptFooterNote.isNotEmpty ? settings.receiptFooterNote : 'Thank you! Visit Again.',
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> printReceipt({
    required Invoice invoice,
    required RestaurantSettings settings,
  }) async {
    final pdfBytes = await generateThermalReceipt(invoice: invoice, settings: settings);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Bill_${invoice.invoiceNumber}',
    );
  }

  static Future<Uint8List> generateSplitSlipThermalReceipt({
    required Invoice invoice,
    required PayerSplit split,
    required RestaurantSettings settings,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final rollWidthMm = settings.thermalPaperWidth == 58 ? 54.0 : 72.0;
    final pageFormat = PdfPageFormat(
      rollWidthMm * PdfPageFormat.mm,
      double.infinity,
      marginAll: 4 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                settings.restaurantName.toUpperCase(),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
              ),
              pw.Text('INDIVIDUAL SPLIT SLIP', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bill: ${invoice.invoiceNumber}', style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Text('Table: ${invoice.tableNumber}', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(dateFormat.format(invoice.issuedAt), style: const pw.TextStyle(fontSize: 7)),
                  pw.Text(split.label, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              if (split.customerName != null && split.customerName!.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text('Payer: ${split.customerName}', style: const pw.TextStyle(fontSize: 7)),
              ],
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Split Share Amount:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Rs. ${split.amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Payment Tender:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(split.paymentMode.toUpperCase(), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.Text('Total Table Bill: Rs. ${invoice.grandTotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.Text(
                settings.receiptFooterNote.isNotEmpty ? settings.receiptFooterNote : 'Thank you! Visit Again.',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  static Future<void> printSplitSlip({
    required Invoice invoice,
    required PayerSplit split,
    required RestaurantSettings settings,
  }) async {
    final pdfBytes = await generateSplitSlipThermalReceipt(invoice: invoice, split: split, settings: settings);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Split_${invoice.invoiceNumber}_${split.label.replaceAll(" ", "_")}',
    );
  }
}
