import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/menu_item.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';

class IngredientsEditorDialog {
  static void show(
    BuildContext context,
    PosProvider provider,
    MenuItem item,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _IngredientsEditorContent(
        provider: provider,
        item: item,
      ),
    );
  }
}

class _IngredientsEditorContent extends StatefulWidget {
  final PosProvider provider;
  final MenuItem item;

  const _IngredientsEditorContent({
    required this.provider,
    required this.item,
  });

  @override
  State<_IngredientsEditorContent> createState() =>
      _IngredientsEditorContentState();
}

class _IngredientsEditorContentState
    extends State<_IngredientsEditorContent> {
  late List<_IngredientRow> _rows;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _rows = widget.item.ingredients
        .map((ing) => _IngredientRow(
              nameController: TextEditingController(text: ing.name),
              qtyController: TextEditingController(
                  text: ing.qty > 0 ? ing.qty.toStringAsFixed(ing.qty == ing.qty.roundToDouble() ? 0 : 2) : ''),
              unitValue: kIngredientUnits.contains(ing.unit) ? ing.unit : 'pcs',
              costPerUnitController: TextEditingController(
                  text: ing.costPerUnit > 0 ? ing.costPerUnit.toStringAsFixed(2) : ''),
            ))
        .toList();
    if (_rows.isEmpty) _addRow();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.nameController.dispose();
      row.qtyController.dispose();
      row.costPerUnitController.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _rows.add(_IngredientRow(
        nameController: TextEditingController(),
        qtyController: TextEditingController(),
        unitValue: 'pcs',
        costPerUnitController: TextEditingController(),
      ));
    });
  }

  void _removeRow(int index) {
    setState(() {
      _rows[index].nameController.dispose();
      _rows[index].qtyController.dispose();
      _rows[index].costPerUnitController.dispose();
      _rows.removeAt(index);
    });
  }

  double _rowLineCost(_IngredientRow row) {
    final qty = double.tryParse(row.qtyController.text.trim().replaceAll(',', '.')) ?? 0.0;
    final cpu = double.tryParse(row.costPerUnitController.text.trim().replaceAll(',', '.')) ?? 0.0;
    if (qty > 0 && cpu > 0) return qty * cpu;
    return 0.0;
  }

  double get _totalCost => _rows.fold(0.0, (sum, r) => sum + _rowLineCost(r));

  double? get _marginPercent {
    if (_rows.every((r) => r.nameController.text.trim().isEmpty) || widget.item.price <= 0) {
      return null;
    }
    final cost = _totalCost;
    return ((widget.item.price - cost) / widget.item.price) * 100;
  }

  Color _marginColor(double margin) {
    if (margin >= 60) return CelestialTheme.emeraldReady;
    if (margin >= 35) return CelestialTheme.amberBrewing;
    return CelestialTheme.roseAlert;
  }

  String _marginLabel(double margin) {
    if (margin >= 60) return 'Healthy Margin';
    if (margin >= 35) return 'Moderate Margin';
    return 'Thin Margin — Review Pricing';
  }

  Future<void> _save(BuildContext ctx) async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 200));

    final ingredients = _rows
        .where((r) => r.nameController.text.trim().isNotEmpty)
        .map((r) => Ingredient(
              name: r.nameController.text.trim(),
              qty: double.tryParse(r.qtyController.text.trim().replaceAll(',', '.')) ?? 0.0,
              unit: r.unitValue,
              costPerUnit: double.tryParse(r.costPerUnitController.text.trim().replaceAll(',', '.')) ?? 0.0,
            ))
        .toList();

    final updated = widget.item.copyWith(ingredients: ingredients);
    widget.provider.updateMenuItem(updated);

    if (ctx.mounted) Navigator.pop(ctx);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final margin = _marginPercent;

    return AlertDialog(
      backgroundColor: CelestialTheme.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  CelestialTheme.goldPrimary.withValues(alpha: 0.3),
                  CelestialTheme.goldPrimary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('🧮', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingredient Cost Calculator',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: CelestialTheme.goldLight,
                  ),
                ),
                Text(
                  widget.item.name,
                  style: const TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: CelestialTheme.textMuted, size: 18),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 540,
        child: StatefulBuilder(
          builder: (context, setInnerState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),

                // Column Headers
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: _headerLabel('Ingredient'),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(width: 58, child: _headerLabel('Qty', center: true)),
                      const SizedBox(width: 6),
                      SizedBox(width: 68, child: _headerLabel('Unit', center: true)),
                      const SizedBox(width: 6),
                      SizedBox(width: 78, child: _headerLabel('Cost/Unit ₱', center: true)),
                      const SizedBox(width: 6),
                      SizedBox(width: 68, child: _headerLabel('Line Cost', center: true)),
                      const SizedBox(width: 28),
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // Ingredient Rows
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: isMobile ? 200 : 260),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _rows.length,
                    itemBuilder: (ctx, index) {
                      final row = _rows[index];
                      final lineCost = _rowLineCost(row);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            // Name
                            Expanded(
                              flex: 4,
                              child: _buildTextField(
                                controller: row.nameController,
                                hint: 'Ingredient name…',
                                onChanged: (_) => setInnerState(() {}),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Qty
                            SizedBox(
                              width: 58,
                              child: _buildNumField(
                                controller: row.qtyController,
                                hint: '0',
                                onChanged: (_) => setInnerState(() {}),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Unit dropdown
                            SizedBox(
                              width: 68,
                              child: _buildUnitDropdown(
                                value: row.unitValue,
                                onChanged: (v) {
                                  if (v != null) {
                                    setInnerState(() => row.unitValue = v);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Cost per unit
                            SizedBox(
                              width: 78,
                              child: _buildNumField(
                                controller: row.costPerUnitController,
                                hint: '0.00',
                                prefix: '₱',
                                onChanged: (_) => setInnerState(() {}),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Line cost (read-only)
                            SizedBox(
                              width: 68,
                              child: Container(
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: lineCost > 0
                                      ? CelestialTheme.emeraldReady.withValues(alpha: 0.08)
                                      : CelestialTheme.bgCard,
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: lineCost > 0
                                        ? CelestialTheme.emeraldReady.withValues(alpha: 0.3)
                                        : Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: Text(
                                  lineCost > 0 ? '₱${lineCost.toStringAsFixed(2)}' : '—',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: lineCost > 0 ? CelestialTheme.emeraldReady : CelestialTheme.textSubtle,
                                  ),
                                ),
                              ),
                            ),
                            // Remove
                            SizedBox(
                              width: 28,
                              child: IconButton(
                                onPressed: _rows.length > 1
                                    ? () {
                                        _removeRow(index);
                                        setInnerState(() {});
                                      }
                                    : null,
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  size: 15,
                                  color: _rows.length > 1
                                      ? CelestialTheme.roseAlert
                                      : CelestialTheme.textSubtle,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Total row
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'TOTAL INGREDIENT COST',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '₱${_totalCost.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.goldLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Add row button
                TextButton.icon(
                  onPressed: () {
                    _addRow();
                    setInnerState(() {});
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 14, color: CelestialTheme.goldPrimary),
                  label: Text('Add Ingredient',
                      style: TextStyle(fontSize: 12, color: CelestialTheme.goldPrimary)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  ),
                ),

                // ── Summary Card ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        CelestialTheme.bgCard,
                        CelestialTheme.bgDark.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: margin != null
                          ? _marginColor(margin).withValues(alpha: 0.4)
                          : CelestialTheme.goldPrimary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _SummaryTile(
                            icon: '🧪',
                            label: 'Ingredient Cost',
                            value: '₱${_totalCost.toStringAsFixed(2)}',
                            valueColor: CelestialTheme.roseAlert,
                          ),
                          _divider(),
                          _SummaryTile(
                            icon: '🏷️',
                            label: 'Selling Price',
                            value: '₱${widget.item.price.toStringAsFixed(2)}',
                            valueColor: CelestialTheme.textLight,
                          ),
                          _divider(),
                          _SummaryTile(
                            icon: '💰',
                            label: 'Gross Profit',
                            value: margin != null
                                ? '₱${(widget.item.price - _totalCost).toStringAsFixed(2)}'
                                : '—',
                            valueColor: margin != null
                                ? CelestialTheme.emeraldReady
                                : CelestialTheme.textMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (margin != null) ...[
                        Row(
                          children: [
                            const Text('📈 ', style: TextStyle(fontSize: 12)),
                            Text('Profit Margin: ',
                                style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted)),
                            Text(
                              '${margin.toStringAsFixed(1)}%',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _marginColor(margin),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (margin.clamp(0, 100) / 100),
                                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                                  valueColor: AlwaysStoppedAnimation<Color>(_marginColor(margin)),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const SizedBox(width: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _marginColor(margin).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _marginLabel(margin),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _marginColor(margin),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            const Text('📈 ', style: TextStyle(fontSize: 12)),
                            Text(
                              'Enter qty & cost/unit above to see profit margin',
                              style: TextStyle(
                                fontSize: 11,
                                color: CelestialTheme.textSubtle,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : () => _save(context),
          icon: _isSaving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: CelestialTheme.bgDark),
                )
              : const Icon(Icons.save_rounded, size: 15),
          label: Text(_isSaving ? 'Saving…' : 'Save Ingredients'),
          style: ElevatedButton.styleFrom(
            backgroundColor: CelestialTheme.goldPrimary,
            foregroundColor: CelestialTheme.bgDark,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _headerLabel(String text, {bool center = false}) => Text(
        text.toUpperCase(),
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: CelestialTheme.textMuted,
          letterSpacing: 0.4,
        ),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: CelestialTheme.textLight, fontSize: 11),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 10, color: CelestialTheme.textSubtle),
        filled: true,
        fillColor: CelestialTheme.bgCard,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.6)),
        ),
      ),
    );
  }

  Widget _buildNumField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    String? prefix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      textAlign: TextAlign.center,
      style: GoogleFonts.outfit(
        color: CelestialTheme.goldLight,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 10, color: CelestialTheme.textSubtle),
        prefixText: prefix,
        prefixStyle: const TextStyle(fontSize: 10, color: CelestialTheme.goldPrimary),
        filled: true,
        fillColor: CelestialTheme.goldPrimary.withValues(alpha: 0.06),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.6)),
        ),
      ),
    );
  }

  Widget _buildUnitDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: CelestialTheme.bgCard,
          style: const TextStyle(color: CelestialTheme.textLight, fontSize: 11),
          isExpanded: true,
          items: kIngredientUnits
              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 36,
        color: Colors.white.withValues(alpha: 0.08),
        margin: const EdgeInsets.symmetric(horizontal: 10),
      );
}

class _IngredientRow {
  final TextEditingController nameController;
  final TextEditingController qtyController;
  String unitValue;
  final TextEditingController costPerUnitController;

  _IngredientRow({
    required this.nameController,
    required this.qtyController,
    required this.unitValue,
    required this.costPerUnitController,
  });
}

class _SummaryTile extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: CelestialTheme.textMuted, letterSpacing: 0.3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
