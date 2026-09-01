import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import 'receipt_dialog.dart';
import '../services/receipt_pdf_service.dart';

class CheckoutModal extends StatefulWidget {
  const CheckoutModal({super.key});

  @override
  State<CheckoutModal> createState() => _CheckoutModalState();
}

class _CheckoutModalState extends State<CheckoutModal> {
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  final TextEditingController _cashTenderedController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  double _amountTendered = 0.0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final posProvider = Provider.of<PosProvider>(context, listen: false);
    _amountTendered = posProvider.cartGrandTotal;
    _cashTenderedController.text = _amountTendered.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _cashTenderedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _selectCashPreset(double amount) {
    setState(() {
      _amountTendered = amount;
      _cashTenderedController.text = amount.toStringAsFixed(0);
    });
  }

  void _processPayment() async {
    final posProvider = Provider.of<PosProvider>(context, listen: false);
    final total = posProvider.cartGrandTotal;

    if (_selectedMethod == PaymentMethod.cash && _amountTendered < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Tendered amount cannot be less than total due!'),
          backgroundColor: CelestialTheme.roseAlert,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    // Simulate quick processing delay for realistic UX
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    final createdOrder = posProvider.completeCheckout(
      paymentMethod: _selectedMethod,
      amountTendered: _selectedMethod == PaymentMethod.cash ? _amountTendered : total,
      specialOrderNotes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    setState(() => _isProcessing = false);
    Navigator.pop(context); // Close checkout modal

    // Auto-print thermal receipt to POS printer
    ReceiptPdfService.printReceipt(
      order: createdOrder,
      posProvider: posProvider,
    ).catchError((err) {
      debugPrint('Auto-print receipt error: $err');
    });

    // Open Receipt Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => ReceiptDialog(order: createdOrder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final total = posProvider.cartGrandTotal;
    final changeDue = (_amountTendered - total).clamp(0.0, double.infinity);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: isMobile ? double.infinity : 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * (isMobile ? 0.94 : 0.9),
        ),
        decoration: BoxDecoration(
          color: CelestialTheme.bgSurface,
          borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
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
            // Modal Header
            _buildHeader(posProvider, isMobile),

            const Divider(height: 1),

            // Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total Banner
                    _buildTotalBanner(total, isMobile),

                    const SizedBox(height: 16),

                    // Payment Method Selector Tabs
                    Text(
                      'Payment Method',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CelestialTheme.goldLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildMethodTabs(isMobile),

                    const SizedBox(height: 16),

                    // Method-specific Content
                    if (_selectedMethod == PaymentMethod.cash)
                      _buildCashSection(total, changeDue, isMobile)
                    else
                      _buildMobilePaySection(total),

                    const SizedBox(height: 16),

                    // Order Notes
                    Text(
                      'Order Memo / Table Instructions',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: CelestialTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _notesController,
                      style: const TextStyle(fontSize: 13, color: CelestialTheme.textLight),
                      decoration: InputDecoration(
                        hintText: 'e.g. VIP guest, take out separate bag, extra napkins...',
                        hintStyle: const TextStyle(color: CelestialTheme.textSubtle, fontSize: 12),
                        filled: true,
                        fillColor: CelestialTheme.bgCard,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: CelestialTheme.goldPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // Modal Footer with Charge Button
            _buildFooter(total, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(PosProvider provider, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(isMobile ? 20 : 24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Checkout & Payment',
                    style: GoogleFonts.outfit(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: CelestialTheme.textLight,
                    ),
                  ),
                  Text(
                    '${provider.orderType.label} • ${provider.orderType == OrderType.dineIn ? provider.tableNumber : provider.customerName}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: CelestialTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: CelestialTheme.textMuted),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalBanner(double total, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 20,
        vertical: isMobile ? 12 : 16,
      ),
      decoration: BoxDecoration(
        gradient: CelestialTheme.brownGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AMOUNT DUE',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: CelestialTheme.goldLight,
                ),
              ),
              Text(
                'Includes applied discounts',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  color: CelestialTheme.textMuted,
                ),
              ),
            ],
          ),
          Text(
            '₱${total.toStringAsFixed(0)}',
            style: GoogleFonts.outfit(
              fontSize: isMobile ? 24 : 30,
              fontWeight: FontWeight.bold,
              color: CelestialTheme.goldLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTabs(bool isMobile) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: isMobile ? 2.6 : 2.8,
      children: PaymentMethod.values.map((method) {
        final isSelected = _selectedMethod == method;

        return InkWell(
          onTap: () => setState(() => _selectedMethod = method),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? CelestialTheme.goldPrimary.withValues(alpha: 0.18)
                  : CelestialTheme.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? CelestialTheme.goldPrimary
                    : Colors.white.withValues(alpha: 0.08),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(method.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    method.label.split(' / ').first,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? CelestialTheme.goldLight
                          : CelestialTheme.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _numPadTap(String key) {
    setState(() {
      final cur = _cashTenderedController.text.replaceAll(',', '');
      if (key == '⌫') {
        if (cur.isNotEmpty) {
          final next = cur.length == 1 ? '0' : cur.substring(0, cur.length - 1);
          _cashTenderedController.text = next;
          _amountTendered = double.tryParse(next) ?? 0.0;
        }
      } else if (key == '00') {
        final next = (cur == '0' || cur.isEmpty) ? '0' : '${cur}00';
        _cashTenderedController.text = next;
        _amountTendered = double.tryParse(next) ?? 0.0;
      } else {
        final next = (cur == '0') ? key : cur + key;
        _cashTenderedController.text = next;
        _amountTendered = double.tryParse(next) ?? 0.0;
      }
    });
  }

  Widget _buildReceivedAndChange(double total, double changeDue, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display — big received amount
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: CelestialTheme.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _amountTendered >= total
                    ? CelestialTheme.goldPrimary.withValues(alpha: 0.5)
                    : CelestialTheme.roseAlert.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.payments_outlined, color: CelestialTheme.goldPrimary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RECEIVED FROM CUSTOMER',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.textSubtle,
                        ),
                      ),
                      TextField(
                        controller: _cashTenderedController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 22 : 28,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.goldLight,
                        ),
                        onChanged: (val) {
                          setState(() {
                            _amountTendered = double.tryParse(val) ?? 0.0;
                          });
                        },
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: '0.00',
                          hintStyle: TextStyle(color: CelestialTheme.textSubtle, fontSize: 22),
                          prefixText: '₱ ',
                          prefixStyle: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.goldPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Change pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _amountTendered >= total
                        ? CelestialTheme.emeraldReady.withValues(alpha: 0.15)
                        : CelestialTheme.roseAlert.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _amountTendered >= total
                          ? CelestialTheme.emeraldReady.withValues(alpha: 0.5)
                          : CelestialTheme.roseAlert.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'CHANGE',
                        style: TextStyle(fontSize: 9, letterSpacing: 0.8, color: CelestialTheme.textSubtle),
                      ),
                      Text(
                        _amountTendered >= total
                            ? '₱${changeDue.toStringAsFixed(0)}'
                            : '—',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _amountTendered >= total
                              ? CelestialTheme.emeraldReady
                              : CelestialTheme.roseAlert,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Quick Preset Bills
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (() {
              final nextFifty = (total / 50).ceil() * 50.0;
              final nextHundred = (total / 100).ceil() * 100.0;
              final nextTwoHundred = (total / 200).ceil() * 200.0;
              final nextFiveHundred = (total / 500).ceil() * 500.0;
              final presets = <double>{
                total,
                if (nextFifty > total) nextFifty,
                if (nextHundred > total) nextHundred,
                if (nextTwoHundred > total) nextTwoHundred,
                if (nextFiveHundred > total) nextFiveHundred,
                1000.0,
              }.toList()..sort();
              return presets.map((amount) {
                final isExact = (amount - total).abs() < 0.01;
                final isSelected = (_amountTendered - amount).abs() < 0.01;
                return ActionChip(
                  label: Text(
                    isExact ? 'Exact' : '₱${amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? CelestialTheme.bgDark : CelestialTheme.goldLight,
                    ),
                  ),
                  backgroundColor: isSelected ? CelestialTheme.goldPrimary : CelestialTheme.bgSurface,
                  side: BorderSide(
                    color: isSelected
                        ? CelestialTheme.goldPrimary
                        : CelestialTheme.brownWarm.withValues(alpha: 0.5),
                  ),
                  onPressed: () => _selectCashPreset(amount),
                );
              }).toList();
            })(),
          ),

          const SizedBox(height: 12),

          // Number Pad Grid
          _buildNumPad(),
        ],
      ),
    );
  }

  Widget _buildNumPad() {
    final keys = ['1','2','3','4','5','6','7','8','9','00','0','⌫'];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      childAspectRatio: 2.4,
      children: keys.map((key) {
        final isDelete = key == '⌫';
        return InkWell(
          onTap: () => _numPadTap(key),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: isDelete
                  ? CelestialTheme.roseAlert.withValues(alpha: 0.15)
                  : CelestialTheme.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDelete
                    ? CelestialTheme.roseAlert.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Center(
              child: Text(
                key,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDelete ? CelestialTheme.roseAlert : CelestialTheme.textLight,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCashSection(double total, double changeDue, bool isMobile) {
    return _buildReceivedAndChange(total, changeDue, isMobile);
  }

  Widget _buildMobilePaySection(double total) {
    final changeDue = (_amountTendered - total).clamp(0.0, double.infinity);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CelestialTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: const Center(
            child: Column(
              children: [
                Icon(Icons.qr_code_scanner_rounded, color: CelestialTheme.goldPrimary, size: 34),
                SizedBox(height: 6),
                Text(
                  'GCash Express QR / Number',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                ),
                SizedBox(height: 2),
                Text(
                  'Scan customer GCash or present merchant GCash QR',
                  style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildReceivedAndChange(total, changeDue, false),
      ],
    );
  }

  Widget _buildFooter(double total, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(isMobile ? 20 : 24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                foregroundColor: CelestialTheme.textMuted,
                padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back', style: TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: CelestialTheme.goldPrimary,
                foregroundColor: CelestialTheme.bgDark,
                elevation: 8,
                shadowColor: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
                padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: CelestialTheme.bgDark,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Charge • ₱${total.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              fontSize: isMobile ? 13 : 15,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
