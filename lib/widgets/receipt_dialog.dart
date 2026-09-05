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

/// Thermal Receipt Dialog designed to replicate physical ATM / POS printer slot
/// with metallic dispenser bezel, thermal paper drop shadow, serrated tear edge,
/// authentic monospace/clean typography, barcode, and live tracking QR.
class ReceiptDialog extends StatefulWidget {
  final Order order;

  const ReceiptDialog({super.key, required this.order});

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> with SingleTickerProviderStateMixin {
  bool _isPrinting = false;
  bool _showQrCode = false;
  late final AnimationController _animController;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _slideAnimation = Tween<double>(begin: -50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final posProvider = Provider.of<PosProvider>(context);
    final isCompact = MediaQuery.of(context).size.width < 500;
    final paperWidth = isCompact ? 320.0 : 360.0;
    final slotWidth = paperWidth + 40.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Action Bar (Print, QR Toggle, Close)
              _buildTopActionBar(context, posProvider),

              const SizedBox(height: 12),

              // Realistic Printer Bezel & Extruding Receipt Paper
              SizedBox(
                width: slotWidth,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    // Thermal Paper Receipt (Animated slide-out from slot)
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: paperWidth,
                        margin: const EdgeInsets.only(top: 22), // starts under the bezel
                        child: ClipPath(
                          clipper: const SerratedReceiptClipper(toothRadius: 7.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCFCFC),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFFFFFFFF),
                                  Color(0xFFFAFAFA),
                                  Color(0xFFF5F5F5),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.40),
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 14),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Realistic slot shadow gradient on the emerging paper
                                Container(
                                  height: 18,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.28),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),

                                // Receipt Inner Printable Area
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Top double dashed line
                                      _buildDashedLine(),
                                      const SizedBox(height: 4),
                                      _buildDashedLine(),
                                      const SizedBox(height: 12),

                                      // Big Bold "RECEIPT" Title (exactly like mockup)
                                      Text(
                                        'RECEIPT',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.outfit(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 4.5,
                                          color: const Color(0xFF1E2024),
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      // Store Branding & Meta
                                      Text(
                                        posProvider.storeName.toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.cinzel(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 2.0,
                                          color: const Color(0xFF4A4D54),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Order #${order.orderNumber.replaceAll('#', '')} • ${DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt)}',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.robotoMono(
                                          fontSize: 9.5,
                                          color: const Color(0xFF757A82),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      Text(
                                        order.orderType == OrderType.dineIn
                                            ? 'Dine In • ${order.tableNumber ?? "Table"}'
                                            : order.orderType.label.toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.robotoMono(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF50555C),
                                        ),
                                      ),

                                      const SizedBox(height: 12),
                                      // Double dashed divider
                                      _buildDashedLine(),
                                      const SizedBox(height: 4),
                                      _buildDashedLine(),
                                      const SizedBox(height: 14),

                                      // Line Items list (matching mockup: 1x Chicken Soup   $ 45.00)
                                      ...order.items.map((item) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 9.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                                textBaseline: TextBaseline.alphabetic,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      '${item.quantity}x ${item.menuItem.name}',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                        color: const Color(0xFF232529),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '₱ ${item.totalPrice.toStringAsFixed(2)}',
                                                    style: GoogleFonts.robotoMono(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF232529),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              // Customizations / notes indented sublines
                                              if (item.customizations.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 16, top: 2),
                                                  child: Text(
                                                    item.customizations.map((c) => '+ ${c.summary}').join(', '),
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 10,
                                                      color: const Color(0xFF7A8089),
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                  ),
                                                ),
                                              if (item.notes != null && item.notes!.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 16, top: 1),
                                                  child: Text(
                                                    'Note: ${item.notes}',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 10,
                                                      color: const Color(0xFF8C7A58),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      }),

                                      if (order.discountAmount > 0) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Discount (${order.discountPercentage.toStringAsFixed(0)}%)',
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                color: const Color(0xFFC0392B),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              '-₱ ${order.discountAmount.toStringAsFixed(2)}',
                                              style: GoogleFonts.robotoMono(
                                                fontSize: 12,
                                                color: const Color(0xFFC0392B),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],

                                      const SizedBox(height: 10),
                                      _buildDashedLine(),
                                      const SizedBox(height: 10),

                                      // TOTAL AMOUNT Row (Bold and prominent like mockup)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'TOTAL AMOUNT',
                                            style: GoogleFonts.outfit(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.0,
                                              color: const Color(0xFF1E2024),
                                            ),
                                          ),
                                          Text(
                                            '₱${order.totalAmount.toStringAsFixed(2)}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                              color: const Color(0xFF151618),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 10),
                                      _buildDashedLine(),
                                      const SizedBox(height: 10),

                                      // Cash and Change payment breakdown
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            order.paymentMethod.label.toUpperCase(),
                                            style: GoogleFonts.outfit(
                                              fontSize: 11.5,
                                              color: const Color(0xFF585D66),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '₱ ${order.amountTendered.toStringAsFixed(2)}',
                                            style: GoogleFonts.robotoMono(
                                              fontSize: 11.5,
                                              color: const Color(0xFF33363B),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'CHANGE',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11.5,
                                              color: const Color(0xFF585D66),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '₱ ${order.changeDue.toStringAsFixed(2)}',
                                            style: GoogleFonts.robotoMono(
                                              fontSize: 11.5,
                                              color: const Color(0xFF33363B),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 16),
                                      // Centered "THANK YOU" Header
                                      Text(
                                        'THANK YOU',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.outfit(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 3.5,
                                          color: const Color(0xFF232529),
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      _buildDashedLine(),
                                      const SizedBox(height: 14),

                                      // Barcode graphic
                                      Center(
                                        child: SizedBox(
                                          width: 210,
                                          height: 38,
                                          child: CustomPaint(
                                            painter: BarcodePainter(seed: order.id.isNotEmpty ? order.id : order.orderNumber),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 6),
                                      Center(
                                        child: Text(
                                          order.orderNumber.toUpperCase(),
                                          style: GoogleFonts.robotoMono(
                                            fontSize: 9,
                                            letterSpacing: 2.0,
                                            color: const Color(0xFF7A808A),
                                          ),
                                        ),
                                      ),

                                      // Live Order Tracking QR (Expandable or Quick View)
                                      if (_showQrCode) ...[
                                        const SizedBox(height: 12),
                                        _buildDashedLine(),
                                        const SizedBox(height: 10),
                                        Center(
                                          child: Column(
                                            children: [
                                              Text(
                                                'SCAN TO TRACK LIVE',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 1.2,
                                                  color: const Color(0xFF474A51),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              InkWell(
                                                onTap: () => OrderTrackingQrDialog.show(context, order),
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: const Color(0xFFDDDDDD)),
                                                  ),
                                                  child: QrImageView(
                                                    data: posProvider.kdsServer.getOrderTrackingUrl(
                                                      order.id,
                                                      orderNumber: order.orderNumber,
                                                    ),
                                                    version: QrVersions.auto,
                                                    size: 96,
                                                    backgroundColor: Colors.white,
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Tap QR to enlarge for customer',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 9,
                                                  color: const Color(0xFF888E96),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 28), // Bottom padding before teeth
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Metallic Printer Dispenser Slot (Positioned directly over the paper top)
                    _buildMetallicPrinterSlot(slotWidth),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Bottom Action Controls
              _buildBottomControls(context, posProvider, order),
            ],
          ),
        ),
      ),
    );
  }

  /// Metallic ATM / Thermal POS Dispenser Slot Bezel
  Widget _buildMetallicPrinterSlot(double width) {
    return Container(
      width: width,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFE4E7EB),
            Color(0xFFC0C7D0),
            Color(0xFF9AA2AC),
            Color(0xFFBCC3CC),
            Color(0xFFE2E6EA),
          ],
          stops: [0.0, 0.18, 0.45, 0.55, 0.85, 1.0],
        ),
        border: Border.all(
          color: const Color(0xFF7E8691),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.35),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Center(
        // Recessed Dark Slit Cavity
        child: Container(
          height: 15,
          margin: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF141618),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF4A515A),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.90),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Top Action Bar (Close button & Live QR toggle)
  Widget _buildTopActionBar(BuildContext context, PosProvider posProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1B181E).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Toggle QR Code button
              TextButton.icon(
                onPressed: () => setState(() => _showQrCode = !_showQrCode),
                icon: Icon(
                  _showQrCode ? Icons.qr_code_rounded : Icons.qr_code_2_rounded,
                  size: 16,
                  color: _showQrCode ? CelestialTheme.emeraldReady : CelestialTheme.goldLight,
                ),
                label: Text(
                  _showQrCode ? 'Hide QR' : 'Track QR',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _showQrCode ? CelestialTheme.emeraldReady : CelestialTheme.goldLight,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              Container(
                width: 1,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: Colors.white.withValues(alpha: 0.2),
              ),
              // Full Screen Tracking QR Button
              IconButton(
                onPressed: () => OrderTrackingQrDialog.show(context, widget.order),
                icon: const Icon(Icons.fullscreen_rounded, size: 18, color: CelestialTheme.goldLight),
                tooltip: 'Enlarge QR for customer',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
              Container(
                width: 1,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: Colors.white.withValues(alpha: 0.2),
              ),
              // Close button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
                tooltip: 'Close',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Bottom Print & New Order Action Buttons
  Widget _buildBottomControls(BuildContext context, PosProvider posProvider, Order order) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Print Thermal Slip Button
        ElevatedButton.icon(
          onPressed: _isPrinting
              ? null
              : () async {
                  setState(() => _isPrinting = true);
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sending receipt slip to thermal printer...'),
                        backgroundColor: Color(0xFF282522),
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
                          content: Text('Printing error: $e'),
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: CelestialTheme.bgDark),
                )
              : const Icon(Icons.print_rounded, size: 18),
          label: Text(
            _isPrinting ? 'Printing...' : 'Print Receipt',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: CelestialTheme.goldPrimary,
            foregroundColor: CelestialTheme.bgDark,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),

        const SizedBox(width: 12),

        // Done / New Order Button
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: Text(
            'Done',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  /// Dashed Horizontal Divider Line with thermal receipt look
  Widget _buildDashedLine({Color color = const Color(0xFF6B707B)}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashSpace = 4.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: 1.1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Custom Clipper creating the serrated / scalloped cutter tear effect
/// along the bottom of the thermal paper receipt
class SerratedReceiptClipper extends CustomClipper<Path> {
  final double toothRadius;

  const SerratedReceiptClipper({this.toothRadius = 7.0});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - toothRadius);

    final diameter = toothRadius * 2;
    final count = (size.width / diameter).floor();
    final actualDiameter = size.width / count;
    final actualRadius = actualDiameter / 2;

    // Cut scalloped notches from right to left curving upwards into paper
    for (int i = count; i > 0; i--) {
      final leftX = (i - 1) * actualDiameter;
      path.arcToPoint(
        Offset(leftX, size.height - toothRadius),
        radius: Radius.circular(actualRadius),
        clockwise: false, // curves inward into the paper!
      );
    }

    path.lineTo(0, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Barcode Custom Painter generating authentic thermal barcode stripes
class BarcodePainter extends CustomPainter {
  final String seed;

  BarcodePainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E2024)
      ..style = PaintingStyle.fill;

    // Deterministic bar widths based on seed characters
    final bytes = seed.codeUnits;
    double currentX = 6.0;
    int idx = 0;

    while (currentX < size.width - 8.0) {
      final byte = bytes[idx % bytes.length];
      final barWidth = ((byte + idx) % 3 + 1.2).toDouble();
      final spaceWidth = (((byte >> 2) + idx) % 3 + 1.2).toDouble();

      canvas.drawRect(
        Rect.fromLTWH(currentX, 0, barWidth, size.height),
        paint,
      );

      currentX += barWidth + spaceWidth;
      idx++;
    }
  }

  @override
  bool shouldRepaint(covariant BarcodePainter oldDelegate) => oldDelegate.seed != seed;
}
