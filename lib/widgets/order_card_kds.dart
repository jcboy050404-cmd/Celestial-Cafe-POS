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
  bool _isActionLoading = false;

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
          color: order.hasKitchenDishes
              ? const Color(0xFFFF5722).withValues(alpha: 0.65)
              : (order.status == OrderStatus.preparing || order.status == OrderStatus.confirmed)
                  ? CelestialTheme.amberBrewing.withValues(alpha: 0.5)
                  : order.status == OrderStatus.ready
                      ? CelestialTheme.emeraldReady.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.08),
          width: order.hasKitchenDishes ? 1.6 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                      if (order.hasKitchenDishes) ...[
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5722).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFF5722).withValues(alpha: 0.7)),
                          ),
                          child: const Text(
                            'KITCHEN',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFF7043),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        order.orderNumber,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: order.hasKitchenDishes ? const Color(0xFFFFE0B2) : CelestialTheme.goldLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            gradient: (order.orderType == OrderType.takeaway || order.orderType == OrderType.delivery)
                                ? const LinearGradient(colors: [Color(0xFFFF9F1C), Color(0xFFE07A00)])
                                : null,
                            color: (order.orderType == OrderType.takeaway || order.orderType == OrderType.delivery)
                                ? null
                                : CelestialTheme.brownWarm.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: (order.orderType == OrderType.takeaway || order.orderType == OrderType.delivery)
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFF9F1C).withValues(alpha: 0.45),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (order.orderType == OrderType.takeaway || order.orderType == OrderType.delivery) ...[
                                const Text('🥡', style: TextStyle(fontSize: 11)),
                                const SizedBox(width: 4),
                              ],
                              Flexible(
                                child: Text(
                                  order.orderType == OrderType.dineIn
                                      ? '${order.orderType.label} • ${(order.tableNumber ?? "Table").replaceAll(RegExp(r"^T+able", caseSensitive: false), "Table")}'
                                      : 'TAKE OUT',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: (order.orderType == OrderType.takeaway || order.orderType == OrderType.delivery)
                                        ? Colors.black
                                        : CelestialTheme.goldLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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

          if (order.orderType == OrderType.takeaway || order.orderType == OrderType.delivery)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9F1C).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFF9F1C).withValues(alpha: 0.6)),
              ),
              child: const Row(
                children: [
                  Text('🛍️', style: TextStyle(fontSize: 13)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'TAKE OUT • PACK IN BAG (USE PAPER CUPS & LIDS)',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFB74D),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Guest: ${order.customerName}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CelestialTheme.textLight),
                      ),
                      if (order.hasKitchenDishes)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5722).withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFF5722).withValues(alpha: 0.65), width: 1.2),
                          ),
                          child: Text(
                            '${order.kitchenDishCount} Kitchen',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFF7043),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      if (order.hasBaristaDrinks)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: CelestialTheme.amberBrewing.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: CelestialTheme.amberBrewing.withValues(alpha: 0.5), width: 1.2),
                          ),
                          child: Text(
                            '${order.baristaDrinkCount} Bar',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: CelestialTheme.amberBrewing,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                    ],
                  ),
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
                    return _buildOrderItemRow(posProvider, order, order.items[idx], idx);
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
                      return _buildOrderItemRow(posProvider, order, order.items[idx], idx);
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

          if (order.items.isNotEmpty && order.items.every((i) => i.isPrepared) && order.status == OrderStatus.preparing)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: CelestialTheme.emeraldReady.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CelestialTheme.emeraldReady.withValues(alpha: 0.45)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: CelestialTheme.emeraldReady),
                  SizedBox(width: 6),
                  Text(
                    '✨ All Items Prepared & Ready!',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: CelestialTheme.emeraldReady),
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

  Widget _buildOrderItemRow(PosProvider posProvider, Order order, OrderItem item, int idx) {
    final isKitchen = item.isKitchenDish;
    final isPrepared = item.isPrepared;
    final isPreparing = order.status == OrderStatus.preparing;
    final isItemTakeout = order.orderType == OrderType.takeaway ||
        order.orderType == OrderType.delivery ||
        (item.notes != null && (
            item.notes!.toLowerCase().contains('take') ||
            item.notes!.toLowerCase().contains('to-go') ||
            item.notes!.toLowerCase().contains('togo') ||
            item.notes!.toLowerCase().contains('balot')));

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

    final itemWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isKitchen)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5722).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFF5722).withValues(alpha: 0.7), width: 1.2),
            ),
            child: const Text(
              'KITCHEN COOK DISH',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: Color(0xFFFF7043),
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox toggle for prepared state
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(right: 7, top: 1.5),
              decoration: BoxDecoration(
                color: isPrepared
                    ? CelestialTheme.emeraldReady
                    : (isPreparing ? Colors.white.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.02)),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isPrepared
                      ? CelestialTheme.emeraldReady
                      : (isPreparing ? Colors.white.withValues(alpha: 0.28) : Colors.white.withValues(alpha: 0.10)),
                  width: 1.4,
                ),
              ),
              child: isPrepared
                  ? const Icon(Icons.check_rounded, size: 13, color: CelestialTheme.bgDark)
                  : null,
            ),
            // Qty badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: isPrepared
                    ? CelestialTheme.emeraldReady.withValues(alpha: 0.3)
                    : (isKitchen ? const Color(0xFFFF5722) : CelestialTheme.goldPrimary),
                borderRadius: BorderRadius.circular(6),
                boxShadow: isKitchen && !isPrepared
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF5722).withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                '${item.quantity}x',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isPrepared
                      ? CelestialTheme.emeraldReady
                      : (isKitchen ? Colors.white : CelestialTheme.bgDark),
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
                            decoration: isPrepared ? TextDecoration.lineThrough : null,
                            color: isPrepared
                                ? CelestialTheme.textMuted
                                : (isKitchen ? const Color(0xFFFFE0B2) : CelestialTheme.textLight),
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
                      if (isItemTakeout) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9F1C).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFF9F1C).withValues(alpha: 0.65)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🥡', style: TextStyle(fontSize: 10)),
                              SizedBox(width: 3),
                              Text(
                                'TAKE OUT',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFFFB74D),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (isPrepared) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: CelestialTheme.emeraldReady.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: CelestialTheme.emeraldReady.withValues(alpha: 0.45)),
                          ),
                          child: const Text(
                            '✓ PREPARED',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: CelestialTheme.emeraldReady,
                              letterSpacing: 0.3,
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
                        style: TextStyle(
                          fontSize: 11,
                          color: isPrepared ? CelestialTheme.textMuted : CelestialTheme.goldLight,
                          fontWeight: FontWeight.w500,
                          decoration: isPrepared ? TextDecoration.lineThrough : null,
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
                          color: isPrepared
                              ? Colors.white.withValues(alpha: 0.05)
                              : CelestialTheme.roseAlert.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: isPrepared
                              ? Border.all(color: Colors.white.withValues(alpha: 0.1))
                              : null,
                        ),
                        child: Text(
                          'Note: ${item.notes}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isPrepared ? CelestialTheme.textMuted : CelestialTheme.roseAlert,
                            fontWeight: FontWeight.bold,
                            decoration: isPrepared ? TextDecoration.lineThrough : null,
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

    final interactiveItem = InkWell(
      onTap: () {
        if (!isPreparing) {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: CelestialTheme.bgCard,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: CelestialTheme.amberBrewing.withValues(alpha: 0.5)),
              ),
              duration: const Duration(seconds: 2),
              content: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: CelestialTheme.amberBrewing, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.status == OrderStatus.confirmed || order.status == OrderStatus.pending
                          ? 'Please tap "Start Brewing / Prep" first before marking items as prepared.'
                          : 'Order #${order.orderNumber} is already ${order.status.label.toLowerCase()}.',
                      style: const TextStyle(fontSize: 12.5, color: CelestialTheme.textLight, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
          return;
        }
        HapticFeedback.selectionClick();
        posProvider.toggleOrderItemPrepared(order.id, idx);
      },
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: isPrepared ? 0.58 : (isPreparing ? 1.0 : 0.82),
        child: isKitchen
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5722).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF5722).withValues(alpha: 0.45), width: 1.2),
                ),
                child: itemWidget,
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                child: itemWidget,
              ),
      ),
    );

    return interactiveItem;
  }

  Widget _buildActionButton(BuildContext context, PosProvider provider, Order order) {
    if (order.status == OrderStatus.confirmed) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isActionLoading
              ? null
              : () => _confirmStatusTransition(
                  context,
                  provider,
                  order,
                  OrderStatus.preparing,
                  title: 'Start Brewing / Prep',
                  actionLabel: 'Start Brewing',
                  color: CelestialTheme.amberBrewing,
                  icon: Icons.coffee_maker_rounded,
                ),
          icon: _isActionLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: CelestialTheme.bgDark),
                )
              : const Icon(Icons.coffee_maker_rounded, size: 17, color: CelestialTheme.bgDark),
          label: Text(
            _isActionLoading ? 'Starting Brew...' : 'Start Brewing / Prep',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CelestialTheme.bgDark),
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
          widget.isMobileList
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
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
                    const SizedBox(height: 6),
                    ElevatedButton.icon(
                      onPressed: _isActionLoading
                          ? null
                          : () => _confirmStatusTransition(
                              context,
                              provider,
                              order,
                              OrderStatus.preparing,
                              title: 'Start Brewing',
                              actionLabel: 'Brew Now',
                              color: CelestialTheme.amberBrewing,
                              icon: Icons.coffee_maker_rounded,
                            ),
                      icon: _isActionLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 1.8, color: CelestialTheme.bgDark),
                            )
                          : const Icon(Icons.coffee_maker_rounded, size: 15, color: CelestialTheme.bgDark),
                      label: const Text('Brew Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CelestialTheme.amberBrewing,
                        foregroundColor: CelestialTheme.bgDark,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                )
              : Row(
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
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isActionLoading
                            ? null
                            : () => _confirmStatusTransition(
                                context,
                                provider,
                                order,
                                OrderStatus.preparing,
                                title: 'Start Brewing',
                                actionLabel: 'Brew Now',
                                color: CelestialTheme.amberBrewing,
                                icon: Icons.coffee_maker_rounded,
                              ),
                        icon: _isActionLoading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 1.8, color: CelestialTheme.bgDark),
                              )
                            : const Icon(Icons.coffee_maker_rounded, size: 15, color: CelestialTheme.bgDark),
                        label: const Text('Brew Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CelestialTheme.amberBrewing,
                          foregroundColor: CelestialTheme.bgDark,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      );
    } else if (order.status == OrderStatus.preparing) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isActionLoading
              ? null
              : () => _confirmStatusTransition(
                  context,
                  provider,
                  order,
                  OrderStatus.ready,
                  title: 'Mark Ready for Pickup',
                  actionLabel: 'Confirm Ready',
                  color: CelestialTheme.emeraldReady,
                  icon: Icons.notifications_active_rounded,
                ),
          icon: _isActionLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: CelestialTheme.bgDark),
                )
              : const Icon(Icons.notifications_active_rounded, size: 16),
          label: Text(_isActionLoading ? 'Marking Ready...' : 'Mark Ready for Pickup'),
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
          onPressed: _isActionLoading
              ? null
              : () => _confirmStatusTransition(
                  context,
                  provider,
                  order,
                  OrderStatus.completed,
                  title: 'Complete & Hand Over',
                  actionLabel: 'Complete Order',
                  color: const Color(0xFF22C55E),
                  icon: Icons.check_circle_rounded,
                ),
          icon: _isActionLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
          label: Text(
            _isActionLoading ? 'Completing...' : 'Complete & Hand Over',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
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
    final checkedIndices = <int>{};
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
                        ? '${order.orderType.label} • ${(order.tableNumber ?? "Table").replaceAll(RegExp(r"^T+able", caseSensitive: false), "Table")}'
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
                StatefulBuilder(
                  builder: (context, setChecklistState) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        children: List.generate(order.items.length, (idx) {
                          final item = order.items[idx];
                          final isChecked = checkedIndices.contains(idx);
                          final customsText = item.customizations.map((c) => c.optionName).join(', ');
                          return InkWell(
                            onTap: () {
                              setChecklistState(() {
                                if (isChecked) {
                                  checkedIndices.remove(idx);
                                } else {
                                  checkedIndices.add(idx);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                    size: 16,
                                    color: CelestialTheme.goldPrimary,
                                  ),
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
                            ),
                          );
                        }),
                      ),
                    );
                  },
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
          Builder(
            builder: (ctx) {
              bool isSubmitting = false;
              return StatefulBuilder(
                builder: (ctx, setDialogState) {
                  return ElevatedButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setDialogState(() => isSubmitting = true);
                            if (mounted) setState(() => _isActionLoading = true);
                            HapticFeedback.heavyImpact();
                            await Future.delayed(const Duration(milliseconds: 280));
                            provider.updateOrderStatus(order.id, nextStatus);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) setState(() => _isActionLoading = false);
                          },
                    icon: isSubmitting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: color == const Color(0xFF22C55E) ? Colors.white : CelestialTheme.bgDark,
                            ),
                          )
                        : Icon(icon, size: 16, color: color == const Color(0xFF22C55E) ? Colors.white : CelestialTheme.bgDark),
                    label: Text(
                      isSubmitting
                          ? (nextStatus == OrderStatus.preparing
                              ? 'Starting Brew...'
                              : nextStatus == OrderStatus.ready
                                  ? 'Marking Ready...'
                                  : 'Completing...')
                          : actionLabel,
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
                  );
                },
              );
            },
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
