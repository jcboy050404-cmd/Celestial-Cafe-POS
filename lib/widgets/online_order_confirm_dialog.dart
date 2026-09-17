import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../services/auth_service.dart';
import '../theme/celestial_theme.dart';
import 'top_notification.dart';

/// Modal dialog that allows the cashier or store owner to review incoming
/// customer online orders and confirm them directly into the kitchen queue.
class OnlineOrderConfirmDialog extends StatefulWidget {
  final Order order;

  const OnlineOrderConfirmDialog({super.key, required this.order});

  static Future<void> show(BuildContext context, Order order) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => OnlineOrderConfirmDialog(order: order),
    );
  }

  @override
  State<OnlineOrderConfirmDialog> createState() => _OnlineOrderConfirmDialogState();
}

class _OnlineOrderConfirmDialogState extends State<OnlineOrderConfirmDialog> {
  bool _isProcessing = false;

  Future<void> _handleConfirm() async {
    setState(() => _isProcessing = true);
    final pos = Provider.of<PosProvider>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);

    final cashierName = auth.currentUser?.displayName ??
        (auth.currentUser?.email.split('@').first ?? 'Cashier');

    final success = await pos.acceptOnlineOrder(
      widget.order,
      cashierName: cashierName,
    );

    if (!mounted) return;
    if (success) {
      TopNotification.showSuccess(
        context,
        'Online Order ${widget.order.orderNumber} confirmed by $cashierName & sent to kitchen!',
      );
    } else {
      TopNotification.show(
        context,
        message: 'Order confirmed locally. Cloud sync will update once connected.',
        icon: Icons.cloud_off_rounded,
      );
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleReject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.5)),
        ),
        title: Text(
          'Reject Online Order?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: CelestialTheme.roseAlert),
        ),
        content: Text(
          'Are you sure you want to decline Order ${widget.order.orderNumber} from ${widget.order.customerName}?',
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: CelestialTheme.roseAlert),
            child: const Text('Yes, Reject', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      final pos = Provider.of<PosProvider>(context, listen: false);
      await pos.cancelOnlineOrder(widget.order);
      if (mounted) {
        TopNotification.show(
          context,
          message: 'Order ${widget.order.orderNumber} was declined.',
          icon: Icons.cancel_rounded,
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 24,
      ),
      child: Material(
        color: CelestialTheme.bgSurface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CelestialTheme.goldPrimary.withValues(alpha: 0.25),
                      CelestialTheme.caramelAccent.withValues(alpha: 0.1),
                    ],
                  ),
                  border: Border(bottom: BorderSide(color: CelestialTheme.borderWarm)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: CelestialTheme.goldPrimary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.notifications_active_rounded, color: Colors.black, size: 22),
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
                                order.orderNumber,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.goldLight,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: CelestialTheme.amberBrewing.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: CelestialTheme.amberBrewing),
                                ),
                                child: Text(
                                  'PENDING CONFIRMATION',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: CelestialTheme.amberBrewing,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            DateFormat('MMM d, yyyy • hh:mm a').format(order.createdAt),
                            style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: CelestialTheme.textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Scrollable Order Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Info Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: CelestialTheme.bgCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: CelestialTheme.goldPrimary.withValues(alpha: 0.2),
                                  child: Icon(Icons.person_rounded, size: 18, color: CelestialTheme.goldLight),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.customerName,
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: CelestialTheme.textLight,
                                        ),
                                      ),
                                      if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                                        Text(
                                          '📞 ${order.customerPhone}',
                                          style: TextStyle(fontSize: 11.5, color: CelestialTheme.textMuted),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: CelestialTheme.caramelAccent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: CelestialTheme.caramelAccent.withValues(alpha: 0.6)),
                                  ),
                                  child: Text(
                                    order.orderType.label.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: CelestialTheme.caramelAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (order.tableNumber != null && order.tableNumber!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.table_restaurant_outlined, size: 14, color: CelestialTheme.goldLight),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Dine-In Location: ${order.tableNumber}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CelestialTheme.textLight),
                                  ),
                                ],
                              ),
                            ],
                            if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.location_on_outlined, size: 14, color: CelestialTheme.goldLight),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Delivery Address: ${order.deliveryAddress}',
                                      style: TextStyle(fontSize: 12, color: CelestialTheme.textLight),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (order.orderNotes != null && order.orderNotes!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  'Note to Kitchen: "${order.orderNotes}"',
                                  style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Colors.amberAccent),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Items List Header
                      Text(
                        'ORDER ITEMS (${order.items.length})',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.goldLight,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Order Items
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CelestialTheme.bgCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: order.items.length,
                          separatorBuilder: (_, _) => const Divider(height: 12, color: Color(0x1AFFFFFF)),
                          itemBuilder: (context, idx) {
                            final item = order.items[idx];
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${item.quantity}x',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: CelestialTheme.goldLight),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.menuItem.name,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: CelestialTheme.textLight,
                                        ),
                                      ),
                                      if (item.customizations.isNotEmpty)
                                        Text(
                                          item.customizations.map((c) => c.summary).join(' • '),
                                          style: TextStyle(fontSize: 10.5, color: CelestialTheme.textMuted),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₱${item.totalPrice.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: CelestialTheme.textLight,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Bill Total Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: CelestialTheme.bgSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: CelestialTheme.borderWarm),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('PAYMENT METHOD', style: TextStyle(fontSize: 9.5, color: CelestialTheme.textSubtle)),
                                Text(
                                  '${order.paymentMethod.icon} ${order.paymentMethod.label}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('TOTAL DUE', style: TextStyle(fontSize: 9.5, color: CelestialTheme.textSubtle)),
                                Text(
                                  '₱${order.totalAmount.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: CelestialTheme.goldPrimary),
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

              // Action Buttons: Reject vs Confirm
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: CelestialTheme.borderWarm)),
                ),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _handleReject,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.6)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(Icons.close_rounded, size: 16, color: CelestialTheme.roseAlert),
                      label: Text('Decline', style: TextStyle(color: CelestialTheme.roseAlert, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _handleConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CelestialTheme.emeraldReady,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text(
                          _isProcessing ? 'Confirming...' : 'Confirm & Send to Kitchen',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
