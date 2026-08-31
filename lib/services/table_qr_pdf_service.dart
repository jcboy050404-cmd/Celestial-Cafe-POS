import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TableQrPdfService {
  /// Generate a PDF document for a single table QR stand
  static Future<Uint8List> generateSingleTablePdf({
    required String storeName,
    required String tagline,
    required String tableNumber,
    required String tableUrl,
    Uint8List? logoBytes,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      try {
        logoImage = pw.MemoryImage(logoBytes);
      } catch (_) {}
    } else {
      try {
        final byteData = await rootBundle.load('assets/images/Logo.png');
        logoImage = pw.MemoryImage(byteData.buffer.asUint8List());
      } catch (_) {}
    }

    final cleanTable = tableNumber.replaceAll('Table', '').trim();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Center(
            child: _buildTableCardWidget(
              storeName: storeName,
              tagline: tagline,
              tableText: 'TABLE $cleanTable',
              tableUrl: tableUrl,
              logoImage: logoImage,
              width: 320,
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate a batch sheet containing multiple table QR codes (e.g. Tables 1 to 12)
  static Future<Uint8List> generateBatchTablesPdf({
    required String storeName,
    required String tagline,
    required int startTable,
    required int totalTables,
    required String Function(String table) getTableUrlCallback,
    Uint8List? logoBytes,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      try {
        logoImage = pw.MemoryImage(logoBytes);
      } catch (_) {}
    } else {
      try {
        final byteData = await rootBundle.load('assets/images/Logo.png');
        logoImage = pw.MemoryImage(byteData.buffer.asUint8List());
      } catch (_) {}
    }

    // 4 Table QR Cards per A4 Page
    const cardsPerPage = 4;
    final totalPages = (totalTables / cardsPerPage).ceil();

    for (var pageIdx = 0; pageIdx < totalPages; pageIdx++) {
      final pageTables = <int>[];
      for (var i = 0; i < cardsPerPage; i++) {
        final tableNum = startTable + (pageIdx * cardsPerPage) + i;
        if (tableNum < startTable + totalTables) {
          pageTables.add(tableNum);
        }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.GridView(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.72,
              children: pageTables.map((tNum) {
                final tUrl = getTableUrlCallback('$tNum');
                return _buildTableCardWidget(
                  storeName: storeName,
                  tagline: tagline,
                  tableText: 'TABLE $tNum',
                  tableUrl: tUrl,
                  logoImage: logoImage,
                  isCompactGrid: true,
                );
              }).toList(),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Print directly via Native Print Spooler or AirPrint
  static Future<void> printTableQr({
    required String storeName,
    required String tagline,
    required String tableNumber,
    required String tableUrl,
    Uint8List? logoBytes,
  }) async {
    final pdfBytes = await generateSingleTablePdf(
      storeName: storeName,
      tagline: tagline,
      tableNumber: tableNumber,
      tableUrl: tableUrl,
      logoBytes: logoBytes,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${storeName.replaceAll(' ', '_')}_Table_${tableNumber.replaceAll('Table', '').trim()}_QR.pdf',
    );
  }

  /// Print / Export Batch All Tables (e.g. Tables 1-10)
  static Future<void> printBatchTables({
    required String storeName,
    required String tagline,
    required int startTable,
    required int totalTables,
    required String Function(String table) getTableUrlCallback,
    Uint8List? logoBytes,
  }) async {
    final pdfBytes = await generateBatchTablesPdf(
      storeName: storeName,
      tagline: tagline,
      startTable: startTable,
      totalTables: totalTables,
      getTableUrlCallback: getTableUrlCallback,
      logoBytes: logoBytes,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${storeName.replaceAll(' ', '_')}_Tables_${startTable}_to_${startTable + totalTables - 1}_QR_Sheets.pdf',
    );
  }

  /// Internal Widget for Table Card Tent
  static pw.Widget _buildTableCardWidget({
    required String storeName,
    required String tagline,
    required String tableText,
    required String tableUrl,
    pw.MemoryImage? logoImage,
    double? width,
    bool isCompactGrid = false,
  }) {
    final primaryGold = PdfColor.fromHex('#C5A059');
    final darkBrown = PdfColor.fromHex('#1E1720');
    final bgWarm = PdfColor.fromHex('#FDFBF7');
    final accentBrown = PdfColor.fromHex('#432C1D');

    return pw.Container(
      width: width,
      padding: pw.EdgeInsets.symmetric(
        horizontal: isCompactGrid ? 14 : 20,
        vertical: isCompactGrid ? 14 : 20,
      ),
      decoration: pw.BoxDecoration(
        color: bgWarm,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
        border: pw.Border.all(color: primaryGold, width: 2),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Cafe Logo / Title
          if (logoImage != null)
            pw.Container(
              height: isCompactGrid ? 38 : 48,
              width: isCompactGrid ? 38 : 48,
              margin: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Image(logoImage),
            ),

          pw.Text(
            storeName.toUpperCase(),
            style: pw.TextStyle(
              fontSize: isCompactGrid ? 13 : 16,
              fontWeight: pw.FontWeight.bold,
              color: darkBrown,
              letterSpacing: 2,
            ),
            textAlign: pw.TextAlign.center,
          ),

          if (tagline.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2, bottom: 8),
              child: pw.Text(
                tagline.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: isCompactGrid ? 7 : 8,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryGold,
                  letterSpacing: 1.2,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),

          // Table Number Badge
          pw.Container(
            padding: pw.EdgeInsets.symmetric(
              horizontal: isCompactGrid ? 14 : 20,
              vertical: isCompactGrid ? 4 : 6,
            ),
            margin: const pw.EdgeInsets.symmetric(vertical: 4),
            decoration: pw.BoxDecoration(
              color: accentBrown,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Text(
              tableText,
              style: pw.TextStyle(
                fontSize: isCompactGrid ? 14 : 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),

          pw.SizedBox(height: isCompactGrid ? 8 : 12),

          // QR Code Container
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
            ),
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: tableUrl,
              width: isCompactGrid ? 105 : 135,
              height: isCompactGrid ? 105 : 135,
            ),
          ),

          pw.SizedBox(height: isCompactGrid ? 8 : 12),

          // 3-Step Scan Instructions
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F4EFEA'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  '1. Connect to Cafe Wi-Fi / Hotspot',
                  style: pw.TextStyle(fontSize: isCompactGrid ? 7.5 : 8.5, color: darkBrown, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '2. Scan QR code with Phone Camera',
                  style: pw.TextStyle(fontSize: isCompactGrid ? 7.5 : 8.5, color: darkBrown, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '3. Order & Phone buzzes when ready!',
                  style: pw.TextStyle(fontSize: isCompactGrid ? 7.5 : 8.5, color: primaryGold, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
