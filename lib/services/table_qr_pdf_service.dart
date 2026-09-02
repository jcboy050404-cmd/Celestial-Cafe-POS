import 'package:flutter/foundation.dart';
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
              width: 270,
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
  static Future<bool> printTableQr({
    required String storeName,
    required String tagline,
    required String tableNumber,
    required String tableUrl,
    Uint8List? logoBytes,
  }) async {
    try {
      final pdfBytes = await generateSingleTablePdf(
        storeName: storeName,
        tagline: tagline,
        tableNumber: tableNumber,
        tableUrl: tableUrl,
        logoBytes: logoBytes,
      );

      return await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: '${storeName.replaceAll(' ', '_')}_Table_${tableNumber.replaceAll('Table', '').trim()}_QR.pdf',
      );
    } catch (e) {
      debugPrint('Table QR print error (non-fatal): $e');
      return false;
    }
  }

  /// Print / Export Batch All Tables (e.g. Tables 1-10)
  static Future<bool> printBatchTables({
    required String storeName,
    required String tagline,
    required int startTable,
    required int totalTables,
    required String Function(String table) getTableUrlCallback,
    Uint8List? logoBytes,
  }) async {
    try {
      final pdfBytes = await generateBatchTablesPdf(
        storeName: storeName,
        tagline: tagline,
        startTable: startTable,
        totalTables: totalTables,
        getTableUrlCallback: getTableUrlCallback,
        logoBytes: logoBytes,
      );

      return await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: '${storeName.replaceAll(' ', '_')}_Tables_${startTable}_to_${startTable + totalTables - 1}_QR_Sheets.pdf',
      );
    } catch (e) {
      debugPrint('Batch Table QR print error (non-fatal): $e');
      return false;
    }
  }

  /// Internal Widget for Table Card Tent (matched 1:1 to preview & image)
  static pw.Widget _buildTableCardWidget({
    required String storeName,
    required String tagline,
    required String tableText,
    required String tableUrl,
    pw.MemoryImage? logoImage,
    double? width,
    bool isCompactGrid = false,
  }) {
    final darkBrown = PdfColor.fromHex('#1E1720');
    final accentBrown = PdfColor.fromHex('#432C1D');
    final goldText = PdfColor.fromHex('#F5D77F');
    final instructionGrey = PdfColor.fromHex('#4A4A4A');
    final cardBorder = PdfColor.fromHex('#E2DCD5');

    const coffeeCupSvg = '''<svg viewBox="0 0 24 24" width="16" height="16">
      <path d="M2 19h18v2H2z" fill="#1E1720"/>
      <path d="M20 3H4v10c0 2.21 1.79 4 4 4h6c2.21 0 4-1.79 4-4v-3h2c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 5h-2V5h2v3z" fill="#1E1720"/>
    </svg>''';

    final cleanTable = tableText.replaceAll('TABLE', '').replaceAll('Table', '').trim();
    final displayTable = 'TABLE $cleanTable';

    return pw.Container(
      width: width,
      padding: pw.EdgeInsets.symmetric(
        horizontal: isCompactGrid ? 14 : 20,
        vertical: isCompactGrid ? 14 : 18,
      ),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
        border: pw.Border.all(color: cardBorder, width: 1),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Header: Coffee cup icon + Store Name
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: isCompactGrid ? 13 : 15,
                height: isCompactGrid ? 13 : 15,
                margin: const pw.EdgeInsets.only(right: 5),
                child: pw.SvgImage(svg: coffeeCupSvg),
              ),
              pw.Text(
                storeName.toUpperCase(),
                style: pw.TextStyle(
                  font: pw.Font.timesBold(),
                  fontSize: isCompactGrid ? 12 : 14,
                  fontWeight: pw.FontWeight.bold,
                  color: darkBrown,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 3),

          // Table Number Badge: Pill shape with dark brown background and gold text
          pw.Container(
            padding: pw.EdgeInsets.symmetric(
              horizontal: isCompactGrid ? 12 : 14,
              vertical: isCompactGrid ? 2.5 : 3.5,
            ),
            decoration: pw.BoxDecoration(
              color: accentBrown,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
            ),
            child: pw.Text(
              displayTable,
              style: pw.TextStyle(
                font: pw.Font.helveticaBold(),
                fontSize: isCompactGrid ? 11 : 13,
                fontWeight: pw.FontWeight.bold,
                color: goldText,
                letterSpacing: 1.2,
              ),
            ),
          ),

          pw.SizedBox(height: isCompactGrid ? 10 : 12),

          // QR Code: High contrast, clean without outer grey box
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: tableUrl,
            width: isCompactGrid ? 125 : 155,
            height: isCompactGrid ? 125 : 155,
            color: darkBrown,
          ),

          pw.SizedBox(height: isCompactGrid ? 8 : 10),

          // 3-Step Scan Instructions matching image
          pw.Column(
            children: [
              pw.Text(
                '1. Connect to Cafe Hotspot',
                style: pw.TextStyle(
                  font: pw.Font.helvetica(),
                  fontSize: isCompactGrid ? 8.5 : 10,
                  fontWeight: pw.FontWeight.bold,
                  color: instructionGrey,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '2. Scan QR code with Phone Camera',
                style: pw.TextStyle(
                  font: pw.Font.helvetica(),
                  fontSize: isCompactGrid ? 8.5 : 10,
                  fontWeight: pw.FontWeight.bold,
                  color: instructionGrey,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '3. Order & Phone Buzzes when Ready!',
                style: pw.TextStyle(
                  font: pw.Font.helvetica(),
                  fontSize: isCompactGrid ? 8.5 : 10,
                  fontWeight: pw.FontWeight.bold,
                  color: instructionGrey,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
