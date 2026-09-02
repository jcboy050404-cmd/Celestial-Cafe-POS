import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../services/receipt_pdf_service.dart';
import '../theme/celestial_theme.dart';

class OrderTrackingQrDialog extends StatelessWidget {
  final Order order;

  const OrderTrackingQrDialog({
    super.key,
    required this.order,
  });

  static void show(BuildContext context, Order order) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) => OrderTrackingQrDialog(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final trackingUrl = posProvider.kdsServer.getOrderTrackingUrl(
      order.id,
      orderNumber: order.orderNumber,
    );
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: isMobile ? double.infinity : 440,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: CelestialTheme.bgSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: CelestialTheme.goldPrimary.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.85),
              blurRadius: 35,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: CelestialTheme.brownGradient,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(
                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.25),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CelestialTheme.goldPrimary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: CelestialTheme.goldPrimary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: CelestialTheme.goldLight,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Track Order ${order.orderNumber}',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.goldLight,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Scan to get live sound & vibration alerts when ready',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: CelestialTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: CelestialTheme.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // QR Code Presentation Frame
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: trackingUrl,
                          version: QrVersions.auto,
                          size: isMobile ? 190 : 210,
                          backgroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Order Quick Details Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildDetailItem(
                            label: 'ORDER',
                            value: order.orderNumber,
                            valueColor: CelestialTheme.goldLight,
                          ),
                          Container(width: 1, height: 26, color: Colors.white.withValues(alpha: 0.1)),
                          _buildDetailItem(
                            label: 'CUSTOMER',
                            value: order.customerName.isNotEmpty ? order.customerName : 'Guest',
                          ),
                          Container(width: 1, height: 26, color: Colors.white.withValues(alpha: 0.1)),
                          _buildDetailItem(
                            label: 'TOTAL',
                            value: '₱${order.totalAmount.toStringAsFixed(0)}',
                            valueColor: CelestialTheme.emeraldReady,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Instructions Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CelestialTheme.emeraldReady.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: CelestialTheme.emeraldReady.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.notifications_active_rounded,
                                color: CelestialTheme.emeraldReady,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Live Pickup Notification',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.emeraldReady,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '1. Customer scans this QR code with their phone.\n'
                            '2. Mobile tracker opens with live status (In Queue ➔ Brewing).\n'
                            '3. When marked "Ready", the phone rings, vibrates, and displays the Pickup Claim ticket.',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: CelestialTheme.textLight,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Copy Link Row
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: trackingUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: CelestialTheme.bgCard,
                            content: Text('Order tracking link copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.link_rounded, color: CelestialTheme.goldLight, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                trackingUrl,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: CelestialTheme.textMuted,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'COPY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: CelestialTheme.goldLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Modal Actions Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: CelestialTheme.bgCard,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Printing thermal slip with tracking QR...'),
                              backgroundColor: CelestialTheme.bgCard,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          await ReceiptPdfService.printReceipt(
                            order: order,
                            posProvider: posProvider,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Printing failed: $e'),
                                backgroundColor: CelestialTheme.roseAlert,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Print Slip'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CelestialTheme.goldLight,
                        side: BorderSide(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Done'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CelestialTheme.goldPrimary,
                        foregroundColor: CelestialTheme.bgDark,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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

  Widget _buildDetailItem({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 9,
            letterSpacing: 0.8,
            color: CelestialTheme.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: valueColor ?? CelestialTheme.textLight,
          ),
        ),
      ],
    );
  }
}
