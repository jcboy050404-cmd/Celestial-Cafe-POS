import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';

class ReceiptPdfService {
  /// 80mm Standard POS Thermal Receipt Page Format
  static const PdfPageFormat roll80 = PdfPageFormat(
    80 * PdfPageFormat.mm,
    double.infinity,
    marginLeft: 4 * PdfPageFormat.mm,
    marginRight: 4 * PdfPageFormat.mm,
    marginTop: 6 * PdfPageFormat.mm,
    marginBottom: 8 * PdfPageFormat.mm,
  );

  /// Generate thermal printable receipt PDF bytes
  static Future<Uint8List> generateReceiptPdf({
    required Order order,
    required PosProvider posProvider,
  }) async {
    final pdf = pw.Document();

    // Load store logo if available
    pw.MemoryImage? logoImage;
    if (posProvider.hasCustomLogo && posProvider.customLogoBytes != null) {
      try {
        logoImage = pw.MemoryImage(posProvider.customLogoBytes!);
      } catch (_) {}
    } else {
      try {
        final byteData = await rootBundle.load('assets/images/Logo.png');
        logoImage = pw.MemoryImage(byteData.buffer.asUint8List());
      } catch (_) {}
    }

    String shortCurrency(double amount) => 'P${amount.toStringAsFixed(2)}';
    final dateStr = DateFormat('yyyy-MM-dd  hh:mm a').format(order.createdAt);

    pdf.addPage(
      pw.Page(
        pageFormat: roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // Logo
              if (logoImage != null) ...[
                pw.Container(
                  width: 44,
                  height: 44,
                  alignment: pw.Alignment.center,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(height: 4),
              ],

              // Store Info Header
              pw.Text(
                posProvider.storeName.toUpperCase(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              if (posProvider.storeTagline.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text(
                  posProvider.storeTagline,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                ),
              ],
              if (posProvider.storeAddress.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text(
                  posProvider.storeAddress,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                ),
              ],

              pw.SizedBox(height: 4),
              _buildDashedLine(),
              pw.SizedBox(height: 4),

              // Order Identification
              _buildRow('ORDER TICKET', order.orderNumber, isBold: true, isLarge: true),
              _buildRow('DATE & TIME', dateStr),
              _buildRow(
                'ORDER TYPE',
                order.tableNumber != null && order.tableNumber!.isNotEmpty
                    ? '${order.orderType.label.toUpperCase()} (${order.tableNumber})'
                    : order.orderType.label.toUpperCase(),
                isBold: true,
              ),
              _buildRow('CUSTOMER', order.customerName.isNotEmpty ? order.customerName : 'Guest'),
              _buildRow('CASHIER', order.cashierName.isNotEmpty ? order.cashierName : 'Main POS'),
              _buildRow('PAYMENT STATUS', order.status == OrderStatus.pending ? 'PENDING' : 'PAID', isBold: true),

              pw.SizedBox(height: 4),
              _buildDashedLine(),
              pw.SizedBox(height: 4),

              // Column Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text('ITEM', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text('QTY', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text('AMOUNT', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              _buildSolidLine(),
              pw.SizedBox(height: 3),

              // Itemized List
              ...order.items.map((item) {
                return pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 5,
                            child: pw.Text(
                              item.menuItem.name,
                              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              'x${item.quantity}',
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(fontSize: 8.5),
                            ),
                          ),
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text(
                              shortCurrency(item.totalPrice),
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      // Customizations
                      ...item.customizations.map(
                        (c) => pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 4, top: 1),
                          child: pw.Text(
                            '> ${c.optionName}${c.extraPrice > 0 ? ' (+${shortCurrency(c.extraPrice)})' : ''}',
                            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                          ),
                        ),
                      ),
                      // Item Note
                      if (item.notes != null && item.notes!.trim().isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 4, top: 1),
                          child: pw.Text(
                            '* Note: "${item.notes}"',
                            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                          ),
                        ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 4),
              _buildDashedLine(),
              pw.SizedBox(height: 4),

              // Totals
              _buildRow('SUBTOTAL', shortCurrency(order.subtotal)),
              if (order.discountAmount > 0)
                _buildRow(
                  'DISCOUNT${order.discountPercentage > 0 ? ' (${order.discountPercentage.toStringAsFixed(0)}%)' : ''}',
                  '-${shortCurrency(order.discountAmount)}',
                ),
              if (order.taxAmount > 0)
                _buildRow('TAX / VAT (${order.taxRate}%)', shortCurrency(order.taxAmount)),

              pw.SizedBox(height: 3),
              _buildSolidLine(thickness: 1.2),
              pw.SizedBox(height: 3),

              // Grand Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL AMOUNT',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    shortCurrency(order.totalAmount),
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),

              pw.SizedBox(height: 3),
              _buildSolidLine(thickness: 1.2),
              pw.SizedBox(height: 4),

              // Payment Details
              _buildRow('PAYMENT METHOD', order.paymentMethod.label),
              if (order.amountTendered > 0)
                _buildRow('AMOUNT TENDERED', shortCurrency(order.amountTendered)),
              if (order.changeDue > 0)
                _buildRow('CHANGE DUE', shortCurrency(order.changeDue), isBold: true),

              // Order Notes
              if (order.orderNotes != null && order.orderNotes!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 3),
                _buildDashedLine(),
                pw.SizedBox(height: 3),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    'ORDER NOTES: ${order.orderNotes}',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
                  ),
                ),
              ],

              pw.SizedBox(height: 6),
              _buildDashedLine(),
              pw.SizedBox(height: 6),

              // Live Order Tracking QR Code
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'SCAN TO TRACK ORDER STATUS',
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.BarcodeWidget(
                      data: posProvider.kdsServer.getOrderTrackingUrl(
                        order.id,
                        orderNumber: order.orderNumber,
                      ),
                      barcode: pw.Barcode.qrCode(),
                      width: 62,
                      height: 62,
                      drawText: false,
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Rings & vibrates phone when ready for pickup',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'TICKET: ${order.orderNumber}',
                      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 6),
              pw.Text(
                'THANK YOU FOR VISITING!',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                'Please come again soon.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 6),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Print directly via Native System Printer Spooler
  static Future<bool> printReceipt({
    required Order order,
    required PosProvider posProvider,
  }) async {
    try {
      final pdfBytes = await generateReceiptPdf(
        order: order,
        posProvider: posProvider,
      );

      return await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Receipt_${order.orderNumber.replaceAll('#', '').trim()}',
        format: roll80,
      );
    } catch (e) {
      // Non-fatal: log error so POS workflow never crashes if printer driver or spooler is offline
      debugPrint('Thermal receipt print error (non-fatal): $e');
      return false;
    }
  }

  static pw.Widget _buildRow(String label, String value, {bool isBold = false, bool isLarge = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isLarge ? 9.5 : 8,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isBold ? PdfColors.black : PdfColors.grey800,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: isLarge ? 9.5 : 8,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDashedLine() {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: List.generate(
          36,
          (index) => pw.Expanded(
            child: pw.Container(
              color: index % 2 == 0 ? PdfColors.grey600 : PdfColors.white,
              height: 0.6,
            ),
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildSolidLine({double thickness = 0.6}) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 1),
      height: thickness,
      color: PdfColors.black,
    );
  }
}
