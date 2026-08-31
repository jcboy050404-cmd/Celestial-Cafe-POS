import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import 'customer_order_approval_dialog.dart';

class OrderCardKds extends StatefulWidget {
  final Order order;
  final bool isMobileList;

  const OrderCardKds({super.key, required this.order, this.isMobileList = false});

  @override
  State<OrderCardKds> createState() => _OrderCardKdsState();
}

class _OrderCardKdsState extends State<OrderCardKds> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Color _getTimerColor(int elapsedMinutes) {
    if (elapsedMinutes < 6) return CelestialTheme.emeraldReady;
    if (elapsedMinutes < 14) return CelestialTheme.amberBrewing;
    return CelestialTheme.roseAlert;
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final posProvider = Provider.of<PosProvider>(context, listen: false);
    final elapsedMinutes = DateTime.now().difference(order.createdAt).inMinutes;
    final timerColor = _getTimerColor(elapsedMinutes);

    return Container(
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (order.status == OrderStatus.preparing || order.status == OrderStatus.confirmed)
              ? CelestialTheme.amberBrewing.withValues(alpha: 0.5)
              : order.status == OrderStatus.ready
                  ? CelestialTheme.emeraldReady.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: CelestialTheme.bgSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        order.orderNumber,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.goldLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: CelestialTheme.brownWarm.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            order.orderType == OrderType.dineIn
                                ? '${order.orderType.label} • ${order.tableNumber ?? "Tbl"}'
                                : order.orderType.label,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.goldLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Elapsed Timer Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: timerColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: timerColor.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined, size: 13, color: timerColor),
                          const SizedBox(width: 4),
                          Text(
                            '${elapsedMinutes}m ago',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: timerColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Void / Delete Ticket Button
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: CelestialTheme.roseAlert, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Void / Cancel Ticket',
                      onPressed: () => _confirmVoidTicket(context, posProvider, order),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Guest: ${order.customerName}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CelestialTheme.textLight),
                ),
                Text(
                  '${order.totalItemCount} items',
                  style: const TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Items List
          widget.isMobileList
              ? ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(14),
                  itemCount: order.items.length,
                  separatorBuilder: (ctx, idx) => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Divider(height: 1),
                  ),
                  itemBuilder: (context, idx) {
                    return _buildOrderItemRow(order.items[idx]);
                  },
                )
              : Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: order.items.length,
                    separatorBuilder: (ctx, idx) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Divider(height: 1),
                    ),
                    itemBuilder: (context, idx) {
                      return _buildOrderItemRow(order.items[idx]);
                    },
                  ),
                ),

          if (order.orderNotes != null && order.orderNotes!.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CelestialTheme.amberBrewing.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CelestialTheme.amberBrewing.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: CelestialTheme.amberBrewing),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Memo: ${order.orderNotes}',
                      style: const TextStyle(fontSize: 11, color: CelestialTheme.amberBrewing),
                    ),
                  ),
                ],
              ),
            ),

          // Action Status Button
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: CelestialTheme.bgSurface,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: _buildActionButton(context, posProvider, order),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemRow(OrderItem item) {
    final sizeCustom = item.customizations.where((c) {
      final name = c.optionName.toLowerCase();
      return name.contains('16oz') || name.contains('22oz') ||
          name.contains('16 oz') || name.contains('22 oz');
    }).firstOrNull;

    final otherCustoms = item.customizations.where((c) {
      final name = c.optionName.toLowerCase();
      return !name.contains('16oz') && !name.contains('22oz') &&
          !name.contains('16 oz') && !name.contains('22 oz');
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Qty badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: CelestialTheme.goldPrimary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${item.quantity}x',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: CelestialTheme.bgDark,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item name + SIZE badge on same row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          item.menuItem.name,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.textLight,
                          ),
                        ),
                      ),
                      if (sizeCustom != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: sizeCustom.optionName.toLowerCase().contains('22')
                                ? CelestialTheme.amberBrewing.withValues(alpha: 0.25)
                                : CelestialTheme.blueInfo.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: sizeCustom.optionName.toLowerCase().contains('22')
                                  ? CelestialTheme.amberBrewing
                                  : CelestialTheme.blueInfo,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            sizeCustom.optionName.toLowerCase().contains('22') ? '22 oz' : '16 oz',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: sizeCustom.optionName.toLowerCase().contains('22')
                                  ? CelestialTheme.amberBrewing
                                  : CelestialTheme.blueInfo,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Other customizations below name
                  if (otherCustoms.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        otherCustoms.map((c) => '› ${c.optionName}').join('\n'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: CelestialTheme.goldLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  // Special note
                  if (item.notes != null && item.notes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: CelestialTheme.roseAlert.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Note: ${item.notes}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: CelestialTheme.roseAlert,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, PosProvider provider, Order order) {
    if (order.status == OrderStatus.confirmed) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _confirmStatusTransition(
            context,
            provider,
            order,
            OrderStatus.preparing,
            title: 'Start Brewing / Prep',
            actionLabel: 'Start Brewing',
            color: CelestialTheme.amberBrewing,
            icon: Icons.coffee_maker_rounded,
          ),
          icon: const Icon(Icons.coffee_maker_rounded, size: 17, color: CelestialTheme.bgDark),
          label: const Text(
            'Start Brewing / Prep',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CelestialTheme.bgDark),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: CelestialTheme.amberBrewing,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    } else if (order.status == OrderStatus.pending) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: CelestialTheme.amberBrewing.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: CelestialTheme.amberBrewing.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_top_rounded, size: 13, color: CelestialTheme.amberBrewing),
                SizedBox(width: 4),
                Text(
                  'Awaiting Payment at Cashier',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: CelestialTheme.amberBrewing,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => CustomerOrderApprovalDialog.show(context, order),
                  icon: const Icon(Icons.payments_outlined, size: 15, color: CelestialTheme.bgDark),
                  label: const Text('Review & Pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CelestialTheme.goldPrimary,
                    foregroundColor: CelestialTheme.bgDark,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: () => _confirmStatusTransition(
                  context,
                  provider,
                  order,
                  OrderStatus.preparing,
                  title: 'Start Brewing',
                  actionLabel: 'Brew Now',
                  color: CelestialTheme.amberBrewing,
                  icon: Icons.coffee_maker_rounded,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CelestialTheme.amberBrewing,
                  foregroundColor: CelestialTheme.bgDark,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Brew Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ],
      );
    } else if (order.status == OrderStatus.preparing) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _confirmStatusTransition(
            context,
            provider,
            order,
            OrderStatus.ready,
            title: 'Mark Ready for Pickup',
            actionLabel: 'Confirm Ready',
            color: CelestialTheme.emeraldReady,
            icon: Icons.notifications_active_rounded,
          ),
          icon: const Icon(Icons.notifications_active_rounded, size: 16),
          label: const Text('Mark Ready for Pickup'),
          style: ElevatedButton.styleFrom(
            backgroundColor: CelestialTheme.emeraldReady,
            foregroundColor: CelestialTheme.bgDark,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    } else if (order.status == OrderStatus.ready) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _confirmStatusTransition(
            context,
            provider,
            order,
            OrderStatus.completed,
            title: 'Complete & Hand Over',
            actionLabel: 'Complete Order',
            color: const Color(0xFF22C55E),
            icon: Icons.check_circle_rounded,
          ),
          icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
          label: const Text(
            'Complete & Hand Over',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22C55E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }

    return Center(
      child: Text(
        order.status.label,
        style: const TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
      ),
    );
  }

  void _confirmStatusTransition(
    BuildContext context,
    PosProvider provider,
    Order order,
    OrderStatus nextStatus, {
    required String title,
    required String actionLabel,
    required Color color,
    required IconData icon,
  }) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$title • ${order.orderNumber}',
                    style: GoogleFonts.outfit(
                      color: CelestialTheme.textLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    order.orderType == OrderType.dineIn
                        ? '${order.orderType.label} • ${order.tableNumber ?? "Table"}'
                        : order.orderType.label,
                    style: const TextStyle(fontSize: 11.5, color: CelestialTheme.textMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 380),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notice banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.35)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.checklist_rounded, color: CelestialTheme.goldLight, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Kindly double check if the item is correct and complete before proceeding.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.goldLight,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Order items checklist summary
                Text(
                  'Order Items Checklist (${order.totalItemCount} pcs):',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: CelestialTheme.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CelestialTheme.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: order.items.map((item) {
                      final customsText = item.customizations.map((c) => c.optionName).join(', ');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_box_outline_blank_rounded, size: 16, color: CelestialTheme.goldPrimary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${item.quantity}x ',
                                          style: const TextStyle(
                                            color: CelestialTheme.goldPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        TextSpan(
                                          text: item.menuItem.name,
                                          style: const TextStyle(
                                            color: CelestialTheme.textLight,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (customsText.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        '› $customsText',
                                        style: const TextStyle(fontSize: 11, color: CelestialTheme.goldLight),
                                      ),
                                    ),
                                  if (item.notes != null && item.notes!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Note: "${item.notes}"',
                                        style: const TextStyle(fontSize: 11, color: CelestialTheme.roseAlert, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('Cancel / Review', style: TextStyle(color: CelestialTheme.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              HapticFeedback.heavyImpact();
              provider.updateOrderStatus(order.id, nextStatus);
            },
            icon: Icon(icon, size: 16, color: color == const Color(0xFF22C55E) ? Colors.white : CelestialTheme.bgDark),
            label: Text(
              actionLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color == const Color(0xFF22C55E) ? Colors.white : CelestialTheme.bgDark,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmVoidTicket(BuildContext context, PosProvider provider, Order order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.4)),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: CelestialTheme.roseAlert),
            const SizedBox(width: 8),
            Text(
              'Void Order ${order.orderNumber}?',
              style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel and remove this ticket from the kitchen queue?\n\nAll items (${order.totalItemCount} pcs) will be automatically returned to stock.',
          style: const TextStyle(fontSize: 13, color: CelestialTheme.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Order', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              provider.cancelOrder(order.id, restock: true);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: CelestialTheme.bgCard,
                  content: Text('Order ${order.orderNumber} voided and restocked successfully.'),
                ),
              );
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text('Void Ticket'),
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.roseAlert,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
