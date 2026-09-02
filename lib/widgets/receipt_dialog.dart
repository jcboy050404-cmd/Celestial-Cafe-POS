import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../services/receipt_pdf_service.dart';
import '../theme/celestial_theme.dart';
import 'order_tracking_qr_dialog.dart';

class ReceiptDialog extends StatefulWidget {
  final Order order;

  const ReceiptDialog({super.key, required this.order});

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final posProvider = Provider.of<PosProvider>(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 420,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF141216),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Thermal Receipt Paper Area (Scrollable)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Brand Logo & Header
                    Center(
                      child: Container(
                        height: 52,
                        width: 52,
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: posProvider.hasCustomLogo
                              ? Image.memory(
                                  posProvider.customLogoBytes!,
                                  fit: BoxFit.cover,
                                )
                              : Image.asset(
                                  'assets/images/Logo.png',
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      posProvider.storeName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzel(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.5,
                        color: CelestialTheme.goldPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      posProvider.storeTagline,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: CelestialTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      posProvider.storeAddress,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        color: CelestialTheme.textSubtle,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 16),
                    _buildDashedLine(),
                    const SizedBox(height: 12),

                    // Order Meta
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ORDER: ${order.orderNumber}',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: CelestialTheme.goldLight,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: CelestialTheme.brownWarm.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            order.orderType == OrderType.dineIn
                                ? '${order.orderType.label} • ${order.tableNumber ?? "Table"}'
                                : order.orderType.label.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.goldLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt)}',
                          style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted),
                        ),
                        Text(
                          'Terminal: POS-01',
                          style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted),
                        ),
                      ],
                    ),
                    if (order.customerName.isNotEmpty)
                      Row(
                        children: [
                          Text(
                            'Customer: ${order.customerName}',
                            style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted),
                          ),
                        ],
                      ),

                    const SizedBox(height: 12),
                    _buildDashedLine(),
                    const SizedBox(height: 12),

                    // Itemized Table Header
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            'ITEM',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'QTY',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'PRICE',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Items list
                    ...order.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    item.menuItem.name,
                                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: CelestialTheme.textLight),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${item.quantity}',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(fontSize: 12, color: CelestialTheme.textLight),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '₱${item.totalPrice.toStringAsFixed(0)}',
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: CelestialTheme.goldLight),
                                  ),
                                ),
                              ],
                            ),
                            // Customizations / Modifiers
                            if (item.customizations.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 6, top: 2),
                                child: Text(
                                  item.customizations.map((c) => '• ${c.summary}').join('\n'),
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: CelestialTheme.textMuted,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            if (item.notes != null && item.notes!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 6, top: 2),
                                child: Text(
                                  'Note: "${item.notes}"',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: CelestialTheme.amberWarm,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 12),
                    _buildDashedLine(),
                    const SizedBox(height: 12),

                    // Financial Summary
                    _buildSummaryRow('Subtotal', '₱${order.subtotal.toStringAsFixed(0)}'),
                    if (order.discountAmount > 0)
                      _buildSummaryRow(
                        'Discount (${order.discountPercentage.toStringAsFixed(0)}%)',
                        '-₱${order.discountAmount.toStringAsFixed(0)}',
                        textColor: CelestialTheme.roseAlert,
                      ),
                    const SizedBox(height: 6),
                    _buildDashedLine(),
                    const SizedBox(height: 8),

                    // Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL DUE',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: CelestialTheme.textLight,
                          ),
                        ),
                        Text(
                          '₱${order.totalAmount.toStringAsFixed(0)}',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.goldLight,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    _buildDashedLine(),
                    const SizedBox(height: 10),

                    // Payment method & Change
                    _buildSummaryRow('Payment Method', order.paymentMethod.label),
                    _buildSummaryRow('Tendered', '₱${order.amountTendered.toStringAsFixed(0)}'),
                    if (order.changeDue > 0)
                      _buildSummaryRow(
                        'Change Returned',
                        '₱${order.changeDue.toStringAsFixed(0)}',
                        textColor: CelestialTheme.emeraldReady,
                        isBold: true,
                      ),

                    const SizedBox(height: 16),
                    _buildDashedLine(),
                    const SizedBox(height: 14),

                    // Live Order Tracking QR Section
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.qr_code_scanner_rounded, size: 15, color: CelestialTheme.goldLight),
                              const SizedBox(width: 6),
                              Text(
                                'SCAN TO TRACK ORDER LIVE',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  color: CelestialTheme.goldLight,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () => OrderTrackingQrDialog.show(context, order),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: QrImageView(
                                data: posProvider.kdsServer.getOrderTrackingUrl(
                                  order.id,
                                  orderNumber: order.orderNumber,
                                ),
                                version: QrVersions.auto,
                                size: 120,
                                backgroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Chimes & vibrates phone when ready for pickup',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: CelestialTheme.emeraldReady,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap QR code to show large screen to customer',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              color: CelestialTheme.textSubtle,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),
                    Text(
                      'Salamat sa pagbisita sa Celestial Cafe!\nMay your coffee be celestial & your day blessed',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: CelestialTheme.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Dialog Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: CelestialTheme.bgSurface,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 360;

                  Widget btnQr = OutlinedButton.icon(
                    onPressed: () => OrderTrackingQrDialog.show(context, order),
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: const Text('QR Code'), // Shortened label
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CelestialTheme.goldLight,
                      side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );

                  Widget btnPrint = OutlinedButton.icon(
                    onPressed: _isPrinting
                        ? null
                        : () async {
                            setState(() => _isPrinting = true);
                            try {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Sending thermal slip to POS printer...'),
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
                            } finally {
                              if (mounted) setState(() => _isPrinting = false);
                            }
                          },
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: CelestialTheme.goldLight),
                          )
                        : const Icon(Icons.print_rounded, size: 18),
                    label: Text(_isPrinting ? 'Printing...' : 'Print'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CelestialTheme.goldLight,
                      side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );

                  Widget btnNewOrder = ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('New Order'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CelestialTheme.goldPrimary,
                      foregroundColor: CelestialTheme.bgDark,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        btnNewOrder,
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: btnQr),
                            const SizedBox(width: 8),
                            Expanded(child: btnPrint),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: btnQr),
                      const SizedBox(width: 8),
                      Expanded(child: btnPrint),
                      const SizedBox(width: 8),
                      Expanded(child: btnNewOrder),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? textColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w400,
              color: CelestialTheme.textMuted,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: textColor ?? CelestialTheme.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedLine() {
    return Row(
      children: List.generate(
        30,
        (index) => Expanded(
          child: Container(
            color: index % 2 == 0 ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
            height: 1,
          ),
        ),
      ),
    );
  }
}
