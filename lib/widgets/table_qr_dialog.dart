import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/pos_provider.dart';
import '../services/table_qr_pdf_service.dart';
import '../theme/celestial_theme.dart';

class TableQrDialog extends StatefulWidget {
  const TableQrDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const TableQrDialog(),
    );
  }

  @override
  State<TableQrDialog> createState() => _TableQrDialogState();
}

class _TableQrDialogState extends State<TableQrDialog> {
  int _selectedTable = 1;
  bool _isGeneratingPdf = false;

  Future<void> _printSingleTable(PosProvider provider) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final tableUrl = provider.kdsServer.getTableOrderUrl('$_selectedTable');
      await TableQrPdfService.printTableQr(
        storeName: provider.storeName,
        tagline: provider.storeTagline,
        tableNumber: '$_selectedTable',
        tableUrl: tableUrl,
        logoBytes: provider.customLogoBytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: CelestialTheme.bgCard,
            content: Text('PDF Print Error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  void _showBatchPrintDialog(BuildContext context, PosProvider provider) {
    int totalTablesToPrint = 12;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: CelestialTheme.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
          ),
          title: Row(
            children: [
              const Icon(Icons.print_rounded, color: CelestialTheme.goldPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Print Batch Table QR Sheets',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: CelestialTheme.goldLight,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Generates an A4 PDF document with 4 table stand tent cards per page, ready for acrylic table stands.',
                style: TextStyle(color: CelestialTheme.textLight, fontSize: 12.5, height: 1.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Number of Tables to Print:',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: CelestialTheme.textLight,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [6, 10, 12, 16, 20].map((count) {
                  final isSelected = totalTablesToPrint == count;
                  return ChoiceChip(
                    label: Text('$count Tables'),
                    selected: isSelected,
                    selectedColor: CelestialTheme.goldPrimary,
                    backgroundColor: CelestialTheme.bgCard,
                    labelStyle: TextStyle(
                      color: isSelected ? CelestialTheme.bgDark : CelestialTheme.textLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (_) => setDialogState(() => totalTablesToPrint = count),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isGeneratingPdf = true);
                try {
                  await TableQrPdfService.printBatchTables(
                    storeName: provider.storeName,
                    tagline: provider.storeTagline,
                    startTable: 1,
                    totalTables: totalTablesToPrint,
                    getTableUrlCallback: (tbl) => provider.kdsServer.getTableOrderUrl(tbl),
                    logoBytes: provider.customLogoBytes,
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: CelestialTheme.bgCard,
                        content: Text('PDF Export Error: $e'),
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isGeneratingPdf = false);
                }
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
              label: const Text('Export & Print PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CelestialTheme.goldPrimary,
                foregroundColor: CelestialTheme.bgDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PosProvider>(context);
    final kdsServer = provider.kdsServer;
    final tableUrl = kdsServer.getTableOrderUrl('$_selectedTable');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 740),
        decoration: BoxDecoration(
          color: CelestialTheme.bgSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: CelestialTheme.bgCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: CelestialTheme.goldPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Table QR Code Ordering',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.textLight,
                          ),
                        ),
                        Text(
                          'Offline Self-Ordering & PDF Print Stand',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: CelestialTheme.goldLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: CelestialTheme.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    // Table Selector Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Table:',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.textLight,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'Table $_selectedTable',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.goldLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Quick Table Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(16, (index) {
                          final tableNum = index + 1;
                          final isSelected = _selectedTable == tableNum;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text('Table $tableNum'),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _selectedTable = tableNum),
                              selectedColor: CelestialTheme.goldPrimary,
                              backgroundColor: CelestialTheme.bgCard,
                              labelStyle: TextStyle(
                                color: isSelected ? CelestialTheme.bgDark : CelestialTheme.textLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? CelestialTheme.goldPrimary
                                    : Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Table QR Card Preview
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: CelestialTheme.goldPrimary.withValues(alpha: 0.2),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.coffee_rounded, size: 16, color: Colors.black87),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  provider.storeName.toUpperCase(),
                                  style: GoogleFonts.cinzel(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    letterSpacing: 1.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF432C1D),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'TABLE $_selectedTable',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: CelestialTheme.goldLight,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // QR Code Image
                          SizedBox(
                            height: 160,
                            width: 160,
                            child: QrImageView(
                              data: tableUrl,
                              version: QrVersions.auto,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF1E1720),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF1E1720),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          Text(
                            '1. Connect to Cafe Hotspot\n2. Scan QR code with Phone Camera\n3. Order & Phone Buzzes when Ready!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Copy Link Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link_rounded, color: CelestialTheme.goldLight, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tableUrl,
                              style: const TextStyle(
                                fontSize: 11,
                                color: CelestialTheme.textMuted,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16, color: CelestialTheme.goldLight),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: tableUrl));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: CelestialTheme.bgCard,
                                  content: Text('Table order URL copied to clipboard!'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // PDF Print / Export Actions Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.picture_as_pdf_rounded, color: CelestialTheme.goldPrimary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Print & Export Options',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: CelestialTheme.goldLight,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isGeneratingPdf ? null : () => _printSingleTable(provider),
                                  icon: const Icon(Icons.print_rounded, size: 14),
                                  label: Text(
                                    _isGeneratingPdf ? 'Generating...' : 'Print Table $_selectedTable (PDF)',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: CelestialTheme.goldLight,
                                    side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isGeneratingPdf ? null : () => _showBatchPrintDialog(context, provider),
                                  icon: const Icon(Icons.grid_view_rounded, size: 14),
                                  label: const Text(
                                    'Print All Tables (Batch)',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: CelestialTheme.emeraldReady,
                                    side: BorderSide(color: CelestialTheme.emeraldReady.withValues(alpha: 0.5)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: CelestialTheme.bgCard,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: tableUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: CelestialTheme.bgCard,
                            content: Text('Table $_selectedTable link copied!'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: const Text('Copy Link', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CelestialTheme.goldLight,
                        side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingPdf ? null : () => _printSingleTable(provider),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                      label: const Text('Export PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CelestialTheme.goldPrimary,
                        foregroundColor: CelestialTheme.bgDark,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
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
