import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import '../widgets/ingredients_editor_dialog.dart';

enum _SortField { margin, price, cost, profit }

class FoodCostingScreen extends StatefulWidget {
  const FoodCostingScreen({super.key});

  @override
  State<FoodCostingScreen> createState() => _FoodCostingScreenState();
}

class _FoodCostingScreenState extends State<FoodCostingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final posProvider = Provider.of<PosProvider>(context);

    return Container(
      color: CelestialTheme.bgDark,
      child: Column(
        children: [
          _buildHeader(isMobile, posProvider),
          const Divider(height: 1),
          // Tab bar
          Container(
            color: CelestialTheme.bgSurface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: CelestialTheme.goldPrimary,
              indicatorWeight: 2,
              labelColor: CelestialTheme.goldLight,
              unselectedLabelColor: CelestialTheme.textMuted,
              labelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(icon: Icon(Icons.table_chart_outlined, size: 16), text: 'Menu Cost Table'),
                Tab(icon: Icon(Icons.calculate_rounded, size: 16), text: 'Recipe Calculator'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MenuCostTableTab(isMobile: isMobile),
                _RecipeCalculatorTab(isMobile: isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile, PosProvider provider) {
    final withIng = provider.itemsWithIngredients.length;
    final total = provider.menuItems.length;
    final avg = provider.averageProfitMarginPercent;
    final thin = provider.thinMarginItemsCount;

    final kpiCards = [
      _KpiCard(
        icon: '📊',
        label: 'AVG PROFIT MARGIN',
        value: withIng > 0 ? '${avg.toStringAsFixed(1)}%' : '—',
        sub: '$withIng of $total items costed',
        color: avg >= 60
            ? CelestialTheme.emeraldReady
            : avg >= 35
                ? CelestialTheme.amberBrewing
                : CelestialTheme.goldPrimary,
      ),
      _KpiCard(
        icon: '💰',
        label: 'MOST PROFITABLE',
        value: provider.mostProfitableItem?.name ?? '—',
        sub: provider.mostProfitableItem != null
            ? '${provider.mostProfitableItem!.profitMarginPercent?.toStringAsFixed(1)}% margin'
            : 'Set ingredient costs first',
        color: CelestialTheme.emeraldReady,
        smallValue: true,
      ),
      _KpiCard(
        icon: '🧪',
        label: 'HIGHEST COST ITEM',
        value: provider.highestCostItem?.name ?? '—',
        sub: provider.highestCostItem != null
            ? '₱${provider.highestCostItem!.totalBatchCost.toStringAsFixed(2)} batch cost'
            : 'No costing data yet',
        color: CelestialTheme.amberBrewing,
        smallValue: true,
      ),
      _KpiCard(
        icon: '⚠️',
        label: 'THIN MARGIN ALERTS',
        value: '$thin',
        sub: thin > 0 ? 'items with margin < 35%' : 'All margins look healthy',
        color: thin > 0 ? CelestialTheme.roseAlert : CelestialTheme.emeraldReady,
      ),
    ];

    return Container(
      color: CelestialTheme.bgSurface,
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CelestialTheme.goldPrimary.withValues(alpha: 0.3),
                      CelestialTheme.goldPrimary.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('🧮', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Food Costing & Profit Calculator',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile ? 15 : 18,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.textLight,
                      ),
                    ),
                    Text(
                      'Build recipes, calculate cost per piece & discover your real profit margin',
                      style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // KPI cards
          if (isMobile)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.7,
              children: kpiCards,
            )
          else
            Row(
              children: kpiCards
                  .map((c) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: c,
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 1 — MENU COST TABLE
// ═══════════════════════════════════════════════════════════════════

class _MenuCostTableTab extends StatefulWidget {
  final bool isMobile;
  const _MenuCostTableTab({required this.isMobile});

  @override
  State<_MenuCostTableTab> createState() => _MenuCostTableTabState();
}

class _MenuCostTableTabState extends State<_MenuCostTableTab> {
  _SortField _sortField = _SortField.margin;
  bool _sortAsc = false;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PosProvider>(context);
    var items = List<MenuItem>.from(provider.menuItems);

    // Filter
    if (_search.isNotEmpty) {
      items = items
          .where((m) => m.name.toLowerCase().contains(_search.toLowerCase()))
          .toList();
    }

    // Sort
    items.sort((a, b) {
      double aVal, bVal;
      switch (_sortField) {
        case _SortField.margin:
          aVal = a.profitMarginPercent ?? -999;
          bVal = b.profitMarginPercent ?? -999;
          break;
        case _SortField.price:
          aVal = a.price;
          bVal = b.price;
          break;
        case _SortField.cost:
          aVal = a.costPerPiece;
          bVal = b.costPerPiece;
          break;
        case _SortField.profit:
          aVal = a.price - a.costPerPiece;
          bVal = b.price - b.costPerPiece;
          break;
      }
      return _sortAsc ? aVal.compareTo(bVal) : bVal.compareTo(aVal);
    });

    return Column(
      children: [
        // Toolbar
        Container(
          color: CelestialTheme.bgSurface,
          padding: EdgeInsets.fromLTRB(
              widget.isMobile ? 12 : 20, 8, widget.isMobile ? 12 : 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: CelestialTheme.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                  ),
                  child: TextField(
                    style: const TextStyle(fontSize: 12, color: CelestialTheme.textLight),
                    onChanged: (v) => setState(() => _search = v),
                    decoration: const InputDecoration(
                      hintText: 'Search items…',
                      hintStyle: TextStyle(fontSize: 12, color: CelestialTheme.textSubtle),
                      prefixIcon: Icon(Icons.search_rounded, size: 16, color: CelestialTheme.goldPrimary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('Sort:', style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted)),
              const SizedBox(width: 4),
              ...[
                (_SortField.margin, 'Margin'),
                (_SortField.price, 'Price'),
                (_SortField.cost, 'Cost'),
                (_SortField.profit, 'Profit'),
              ].map((pair) {
                final isActive = _sortField == pair.$1;
                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      if (_sortField == pair.$1) {
                        _sortAsc = !_sortAsc;
                      } else {
                        _sortField = pair.$1;
                        _sortAsc = false;
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? CelestialTheme.goldPrimary.withValues(alpha: 0.2)
                            : CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isActive
                              ? CelestialTheme.goldPrimary.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            pair.$2,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              color: isActive ? CelestialTheme.goldLight : CelestialTheme.textMuted,
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 2),
                            Icon(
                              _sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              size: 10,
                              color: CelestialTheme.goldPrimary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        // Table Header
        Container(
          color: CelestialTheme.bgCard,
          padding: EdgeInsets.symmetric(
            horizontal: widget.isMobile ? 12 : 20,
            vertical: 8,
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: _th('ITEM')),
              if (!widget.isMobile) ...[
                _thW('SELL PRICE', 90),
                _thW('COST/PC', 80),
                _thW('GROSS PROFIT', 100),
              ],
              _thW('MARGIN', 100),
              _thW('', 80),
            ],
          ),
        ),

        // Items list
        Expanded(
          child: items.isEmpty
              ? _emptyState()
              : ListView.separated(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.isMobile ? 8 : 16,
                    vertical: 8,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 6),
                  itemBuilder: (ctx, i) => _buildItemRow(ctx, items[i], provider),
                ),
        ),
      ],
    );
  }

  Widget _buildItemRow(BuildContext context, MenuItem item, PosProvider provider) {
    final margin = item.profitMarginPercent;
    final hasIng = item.ingredients.isNotEmpty;
    final grossProfit = item.price - item.costPerPiece;

    Color marginColor = CelestialTheme.textSubtle;
    if (margin != null) {
      marginColor = margin >= 60
          ? CelestialTheme.emeraldReady
          : margin >= 35
              ? CelestialTheme.amberBrewing
              : CelestialTheme.roseAlert;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isMobile ? 10 : 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasIng
              ? marginColor.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          // Item info
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Text(item.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.textLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item.categoryLabel,
                        style: const TextStyle(fontSize: 9, color: CelestialTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (!widget.isMobile) ...[
            // Sell price
            SizedBox(
              width: 90,
              child: Text(
                '₱${item.price.toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: CelestialTheme.goldLight,
                ),
              ),
            ),
            // Cost/piece
            SizedBox(
              width: 80,
              child: Text(
                hasIng ? '₱${item.costPerPiece.toStringAsFixed(2)}' : '—',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: hasIng ? CelestialTheme.roseAlert : CelestialTheme.textSubtle,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Gross profit
            SizedBox(
              width: 100,
              child: Text(
                hasIng ? '₱${grossProfit.toStringAsFixed(2)}' : '—',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: hasIng
                      ? (grossProfit >= 0 ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert)
                      : CelestialTheme.textSubtle,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],

          // Margin bar
          SizedBox(
            width: 100,
            child: hasIng
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${margin!.toStringAsFixed(1)}%',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: marginColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (margin.clamp(0, 100) / 100),
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(marginColor),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'No cost set',
                    style: TextStyle(fontSize: 10, color: CelestialTheme.textSubtle),
                    textAlign: TextAlign.center,
                  ),
          ),

          // Edit button
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => IngredientsEditorDialog.show(context, provider, item),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  foregroundColor: hasIng ? CelestialTheme.goldPrimary : CelestialTheme.emeraldReady,
                ),
                child: Text(
                  hasIng ? '✏️ Edit' : '+ Set Cost',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: hasIng ? CelestialTheme.goldLight : CelestialTheme.emeraldReady,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _th(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: CelestialTheme.textMuted,
          letterSpacing: 0.6,
        ),
      );

  Widget _thW(String text, double width) => SizedBox(
        width: width,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: CelestialTheme.textMuted,
            letterSpacing: 0.6,
          ),
        ),
      );

  Widget _emptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            Text(
              'No items found',
              style: GoogleFonts.outfit(fontSize: 14, color: CelestialTheme.textLight),
            ),
          ],
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════
// TAB 2 — RECIPE CALCULATOR (Spreadsheet Style)
// ═══════════════════════════════════════════════════════════════════

class _RecipeCalculatorTab extends StatefulWidget {
  final bool isMobile;
  const _RecipeCalculatorTab({required this.isMobile});

  @override
  State<_RecipeCalculatorTab> createState() => _RecipeCalculatorTabState();
}

class _RecipeCalculatorTabState extends State<_RecipeCalculatorTab> {
  MenuItem? _selectedItem;
  // Product/Recipe fields
  final _productNameCtrl = TextEditingController();
  final _batchYieldCtrl = TextEditingController(text: '1');
  final _desiredMarginCtrl = TextEditingController(text: '70');
  final _monthlyOpexCtrl = TextEditingController();
  final _yourSellingPriceCtrl = TextEditingController();
  final _projectedUnitsCtrl = TextEditingController(text: '30');

  // Ingredient rows
  List<_IngRow> _ingRows = [];
  // Other materials rows
  List<_MatRow> _matRows = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addIngRow();
    _addMatRow();
  }

  @override
  void dispose() {
    _productNameCtrl.dispose();
    _batchYieldCtrl.dispose();
    _desiredMarginCtrl.dispose();
    _monthlyOpexCtrl.dispose();
    _yourSellingPriceCtrl.dispose();
    _projectedUnitsCtrl.dispose();
    for (final r in _ingRows) {
      r.dispose();
    }
    for (final r in _matRows) {
      r.dispose();
    }
    super.dispose();
  }

  void _loadFromItem(MenuItem item) {
    setState(() {
      _selectedItem = item;
      _productNameCtrl.text = item.name;
      _batchYieldCtrl.text = '${item.batchYield}';
      _desiredMarginCtrl.text = item.desiredMarginPercent.toStringAsFixed(0);
      _monthlyOpexCtrl.text = item.monthlyOpex > 0 ? item.monthlyOpex.toStringAsFixed(0) : '';
      _yourSellingPriceCtrl.text = item.price.toStringAsFixed(2);

      // Dispose old rows
      for (final r in _ingRows) {
        r.dispose();
      }
      for (final r in _matRows) {
        r.dispose();
      }

      _ingRows = item.ingredients.isNotEmpty
          ? item.ingredients
              .map((ing) => _IngRow(
                    name: ing.name,
                    qty: ing.qty > 0 ? ing.qty.toStringAsFixed(ing.qty == ing.qty.roundToDouble() ? 0 : 2) : '',
                    unit: kIngredientUnits.contains(ing.unit) ? ing.unit : 'pcs',
                    cpu: ing.costPerUnit > 0 ? ing.costPerUnit.toStringAsFixed(2) : '',
                  ))
              .toList()
          : [_IngRow()];

      _matRows = item.otherMaterials.isNotEmpty
          ? item.otherMaterials.map((m) => _MatRow(name: m.name, cost: m.cost.toStringAsFixed(2))).toList()
          : [_MatRow()];
    });
  }

  void _addIngRow() => setState(() => _ingRows.add(_IngRow()));
  void _removeIngRow(int i) {
    setState(() {
      _ingRows[i].dispose();
      _ingRows.removeAt(i);
    });
  }

  void _addMatRow() => setState(() => _matRows.add(_MatRow()));
  void _removeMatRow(int i) {
    setState(() {
      _matRows[i].dispose();
      _matRows.removeAt(i);
    });
  }

  // ── Computed values ──────────────────────────
  double get _totalIngCost => _ingRows.fold(0.0, (s, r) => s + r.lineCost);
  double get _totalMatCost => _matRows.fold(0.0, (s, r) => s + r.matCost);
  double get _totalBatchCost => _totalIngCost + _totalMatCost;
  int get _batchYield => int.tryParse(_batchYieldCtrl.text.trim()) ?? 1;
  double get _desiredMargin => double.tryParse(_desiredMarginCtrl.text.trim()) ?? 70.0;
  double get _monthlyOpex => double.tryParse(_monthlyOpexCtrl.text.trim().replaceAll(',', '')) ?? 0.0;
  double get _costPerPiece => _batchYield > 0 ? _totalBatchCost / _batchYield : _totalBatchCost;
  double get _suggestedPrice =>
      _desiredMargin >= 100 ? _costPerPiece : _costPerPiece / (1 - _desiredMargin / 100);
  double get _profitPerBatch => (_suggestedPrice * _batchYield) - _totalBatchCost;

  double get _yourSellingPrice =>
      double.tryParse(_yourSellingPriceCtrl.text.trim().replaceAll(',', '')) ?? _suggestedPrice;
  double get _profitPerPieceAtYourPrice => _yourSellingPrice - _costPerPiece;
  double get _marginAtYourPrice =>
      _yourSellingPrice > 0 ? (_profitPerPieceAtYourPrice / _yourSellingPrice) * 100 : 0.0;
  double get _breakEvenUnits =>
      _monthlyOpex > 0 && _profitPerPieceAtYourPrice > 0
          ? _monthlyOpex / _profitPerPieceAtYourPrice
          : 0.0;
  int get _projectedUnits => int.tryParse(_projectedUnitsCtrl.text.trim()) ?? 30;
  double get _monthlyProfit => _projectedUnits * _profitPerPieceAtYourPrice;

  Future<void> _saveToItem(BuildContext ctx, PosProvider provider) async {
    if (_selectedItem == null) return;
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 200));

    final ingredients = _ingRows
        .where((r) => r.nameCtrl.text.trim().isNotEmpty)
        .map((r) => Ingredient(
              name: r.nameCtrl.text.trim(),
              qty: double.tryParse(r.qtyCtrl.text.trim()) ?? 0.0,
              unit: r.unit,
              costPerUnit: double.tryParse(r.cpuCtrl.text.trim()) ?? 0.0,
            ))
        .toList();

    final materials = _matRows
        .where((r) => r.nameCtrl.text.trim().isNotEmpty)
        .map((r) => OtherMaterial(
              name: r.nameCtrl.text.trim(),
              cost: double.tryParse(r.costCtrl.text.trim()) ?? 0.0,
            ))
        .toList();

    final updated = _selectedItem!.copyWith(
      ingredients: ingredients,
      otherMaterials: materials,
      batchYield: _batchYield,
      desiredMarginPercent: _desiredMargin,
      monthlyOpex: _monthlyOpex,
    );
    provider.updateMenuItem(updated);
    setState(() {
      _selectedItem = updated;
      _isSaving = false;
    });

    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          backgroundColor: CelestialTheme.emeraldReady,
          content: Text(
            '✅ Recipe saved for ${updated.name}',
            style: const TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PosProvider>(context);
    final isMobile = widget.isMobile;

    return StatefulBuilder(
      builder: (context, setS) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRecipeSelector(provider, setS),
                    const SizedBox(height: 16),
                    _buildProductPanel(setS),
                    const SizedBox(height: 16),
                    _buildIngredientTable(setS),
                    const SizedBox(height: 16),
                    _buildOtherMaterialsTable(setS),
                    const SizedBox(height: 16),
                    _buildOpexCard(setS),
                    const SizedBox(height: 16),
                    _buildCostingSummaryCard(),
                    const SizedBox(height: 16),
                    _buildBreakEvenCard(setS),
                    const SizedBox(height: 16),
                    _buildSaveButton(context, provider),
                  ],
                )
              : Column(
                  children: [
                    _buildRecipeSelector(provider, setS),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT column
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              _buildProductPanel(setS),
                              const SizedBox(height: 16),
                              _buildIngredientTable(setS),
                              const SizedBox(height: 16),
                              _buildOtherMaterialsTable(setS),
                              const SizedBox(height: 16),
                              _buildOpexCard(setS),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        // RIGHT column
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              _buildCostingSummaryCard(),
                              const SizedBox(height: 16),
                              _buildBreakEvenCard(setS),
                              const SizedBox(height: 16),
                              _buildSaveButton(context, provider),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildRecipeSelector(PosProvider provider, StateSetter setS) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor(CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
      child: Row(
        children: [
          const Text('📋', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LOAD FROM MENU ITEM',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: CelestialTheme.textMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<MenuItem>(
                  key: ValueKey(_selectedItem?.id),
                  initialValue: _selectedItem,
                  dropdownColor: CelestialTheme.bgCard,
                  style: const TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                  hint: const Text('Select a menu item to load its recipe…',
                      style: TextStyle(fontSize: 12, color: CelestialTheme.textSubtle)),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: CelestialTheme.bgCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                    ),
                  ),
                  items: provider.menuItems
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text('${m.icon} ${m.name} — ₱${m.price.toStringAsFixed(0)}'),
                          ))
                      .toList(),
                  onChanged: (m) {
                    if (m != null) {
                      _loadFromItem(m);
                      setS(() {});
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductPanel(StateSetter setS) {
    return _section(
      title: 'PRODUCT / RECIPE',
      icon: '🏷️',
      child: Column(
        children: [
          _labeledField('Product Name', _productNameCtrl, setS, hint: 'e.g. Graham Balls'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _labeledField('Batch Yield (pcs)', _batchYieldCtrl, setS,
                    hint: '30', isNum: true),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _labeledField('Desired Profit Margin (%)', _desiredMarginCtrl, setS,
                    hint: '70', isNum: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientTable(StateSetter setS) {
    return _section(
      title: 'INGREDIENT COSTING',
      icon: '🧪',
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(flex: 3, child: _th('INGREDIENT')),
                const SizedBox(width: 6),
                _thW2('QTY', 52),
                const SizedBox(width: 6),
                _thW2('UNIT', 68),
                const SizedBox(width: 6),
                _thW2('COST/UNIT ₱', 80),
                const SizedBox(width: 6),
                _thW2('LINE COST', 72),
                const SizedBox(width: 28),
              ],
            ),
          ),
          // Rows
          ..._ingRows.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _numOrTextInput(row.nameCtrl, 'e.g. Crushed Graham', false, setS),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 52,
                    child: _numOrTextInput(row.qtyCtrl, '0', true, setS),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 68,
                    child: _unitDropdown(row.unit, (v) {
                      if (v != null) setState(() => row.unit = v);
                    }),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 80,
                    child: _numOrTextInput(row.cpuCtrl, '0.00', true, setS, prefix: '₱'),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 72,
                    child: _lineCostBox(row.lineCost),
                  ),
                  SizedBox(
                    width: 28,
                    child: IconButton(
                      onPressed: _ingRows.length > 1 ? () => _removeIngRow(i) : null,
                      icon: Icon(Icons.remove_circle_outline, size: 15,
                          color: _ingRows.length > 1 ? CelestialTheme.roseAlert : CelestialTheme.textSubtle),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ),
                ],
              ),
            );
          }),
          // Total
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _addIngRow,
                  icon: const Icon(Icons.add_circle_outline, size: 14, color: CelestialTheme.goldPrimary),
                  label: const Text('Add Ingredient',
                      style: TextStyle(fontSize: 11, color: CelestialTheme.goldPrimary)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
                Row(
                  children: [
                    Text('TOTAL INGREDIENT COST',
                        style: TextStyle(fontSize: 9, color: CelestialTheme.textMuted, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    _valueBadge('₱${_totalIngCost.toStringAsFixed(2)}', CelestialTheme.goldPrimary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherMaterialsTable(StateSetter setS) {
    return _section(
      title: 'OTHER MATERIALS',
      icon: '📦',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(flex: 4, child: _th('MATERIAL / PACKAGING')),
                const SizedBox(width: 6),
                _thW2('COST ₱', 90),
                const SizedBox(width: 28),
              ],
            ),
          ),
          ..._matRows.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: _numOrTextInput(row.nameCtrl, 'e.g. Cup, Straw, Label…', false, setS),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 90,
                    child: _numOrTextInput(row.costCtrl, '0.00', true, setS, prefix: '₱'),
                  ),
                  SizedBox(
                    width: 28,
                    child: IconButton(
                      onPressed: _matRows.length > 1 ? () => _removeMatRow(i) : null,
                      icon: Icon(Icons.remove_circle_outline, size: 15,
                          color: _matRows.length > 1 ? CelestialTheme.roseAlert : CelestialTheme.textSubtle),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ),
                ],
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _addMatRow,
                  icon: const Icon(Icons.add_circle_outline, size: 14, color: CelestialTheme.goldPrimary),
                  label: const Text('Add Material',
                      style: TextStyle(fontSize: 11, color: CelestialTheme.goldPrimary)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
                Row(
                  children: [
                    Text('TOTAL MATERIALS',
                        style: TextStyle(fontSize: 9, color: CelestialTheme.textMuted, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    _valueBadge('₱${_totalMatCost.toStringAsFixed(2)}', CelestialTheme.amberBrewing),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpexCard(StateSetter setS) {
    return _section(
      title: 'MONTHLY OPEX',
      icon: '🏪',
      child: Row(
        children: [
          Expanded(
            child: _labeledField(
              'Monthly Overhead (Rent + Utilities + Labor) ₱',
              _monthlyOpexCtrl,
              setS,
              hint: '0.00',
              isNum: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostingSummaryCard() {
    final Color marginColor = _marginAtYourPrice >= 60
        ? CelestialTheme.emeraldReady
        : _marginAtYourPrice >= 35
            ? CelestialTheme.amberBrewing
            : CelestialTheme.roseAlert;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1208), Color(0xFF0E0905)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📊', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'COSTING SUMMARY',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: CelestialTheme.goldLight,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFF2A1E10)),
          const SizedBox(height: 10),
          _summaryRow('🧪 Ingredient Cost', '₱${_totalIngCost.toStringAsFixed(2)}', CelestialTheme.roseAlert),
          _summaryRow('📦 Other Materials', '₱${_totalMatCost.toStringAsFixed(2)}', CelestialTheme.amberBrewing),
          const Divider(height: 14, color: Color(0xFF2A1E10)),
          _summaryRow('📊 Total Batch Cost', '₱${_totalBatchCost.toStringAsFixed(2)}', CelestialTheme.textLight, bold: true),
          _summaryRow('🎯 Target Profit Margin', '${_desiredMargin.toStringAsFixed(0)}%', CelestialTheme.goldLight),
          const Divider(height: 14, color: Color(0xFF2A1E10)),
          _summaryRow('💵 Cost / Piece', '₱${_costPerPiece.toStringAsFixed(2)}', CelestialTheme.textLight, bold: true),
          _summaryRow('💰 Suggested Selling Price', '₱${_suggestedPrice.toStringAsFixed(2)}', CelestialTheme.goldLight, bold: true, large: true),
          _summaryRow('📈 Profit / Batch', '₱${_profitPerBatch.toStringAsFixed(2)}',
              _profitPerBatch >= 0 ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert),
          if (_monthlyOpex > 0) ...[
            const Divider(height: 14, color: Color(0xFF2A1E10)),
            _summaryRow('🏪 Monthly OPEX', '₱${_monthlyOpex.toStringAsFixed(2)}', CelestialTheme.textMuted),
          ],
          const SizedBox(height: 8),
          // Margin bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_marginAtYourPrice.clamp(0, 100) / 100),
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(marginColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Profit Margin',
                  style: TextStyle(fontSize: 10, color: CelestialTheme.textMuted)),
              Text(
                '${_marginAtYourPrice.toStringAsFixed(1)}%',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: marginColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakEvenCard(StateSetter setS) {
    final Color beColor = _profitPerPieceAtYourPrice >= 0
        ? CelestialTheme.emeraldReady
        : CelestialTheme.roseAlert;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C1A10), Color(0xFF060D07)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CelestialTheme.emeraldReady.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📐', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'BREAK-EVEN / SALES ANALYSIS',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: CelestialTheme.emeraldReady,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Your selling price input
          Row(
            children: [
              Expanded(
                child: _labeledField(
                  'Your Selling Price ₱',
                  _yourSellingPriceCtrl,
                  setS,
                  hint: _suggestedPrice.toStringAsFixed(2),
                  isNum: true,
                  accentColor: CelestialTheme.emeraldReady,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFF0F2214)),
          const SizedBox(height: 10),
          _summaryRow(
            '💵 Profit / Piece at Your Price',
            '₱${_profitPerPieceAtYourPrice.toStringAsFixed(2)}',
            beColor,
          ),
          _summaryRow(
            '📊 Break-even Margin',
            '${_marginAtYourPrice.toStringAsFixed(1)}%',
            beColor,
          ),
          if (_monthlyOpex > 0)
            _summaryRow(
              '📦 Break-even Units / Month',
              _breakEvenUnits > 0 ? '${_breakEvenUnits.ceil()} pcs' : '—',
              CelestialTheme.textLight,
              bold: true,
            ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFF0F2214)),
          const SizedBox(height: 10),
          // Projected units
          Row(
            children: [
              Expanded(
                child: _labeledField(
                  'Projected Units Sold / Month',
                  _projectedUnitsCtrl,
                  setS,
                  hint: '30',
                  isNum: true,
                  accentColor: CelestialTheme.blueInfo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _summaryRow(
            '💰 Monthly Profit (at $_projectedUnits pcs)',
            '₱${_monthlyProfit.toStringAsFixed(2)}',
            _monthlyProfit >= 0 ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
            bold: true,
            large: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, PosProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _selectedItem == null || _isSaving
            ? null
            : () => _saveToItem(context, provider),
        icon: _isSaving
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: CelestialTheme.bgDark),
              )
            : const Icon(Icons.save_rounded, size: 16),
        label: Text(
          _isSaving
              ? 'Saving…'
              : _selectedItem == null
                  ? 'Select a menu item to save recipe'
                  : 'Save Recipe to "${_selectedItem!.name}"',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedItem != null ? CelestialTheme.goldPrimary : CelestialTheme.bgCard,
          foregroundColor: _selectedItem != null ? CelestialTheme.bgDark : CelestialTheme.textMuted,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ── Small helpers ─────────────────────────────────────────────────

  Widget _section({required String title, required String icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor(Colors.white.withValues(alpha: 0.06)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: CelestialTheme.goldLight,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  BoxDecoration _cardDecor(Color borderColor) => BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      );

  Widget _labeledField(
    String label,
    TextEditingController ctrl,
    StateSetter setS, {
    String hint = '',
    bool isNum = false,
    Color accentColor = CelestialTheme.goldPrimary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: CelestialTheme.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          inputFormatters: isNum ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))] : null,
          style: const TextStyle(color: CelestialTheme.textLight, fontSize: 13),
          onChanged: (_) => setS(() {}),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: CelestialTheme.textSubtle),
            filled: true,
            fillColor: CelestialTheme.bgSurface,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: accentColor.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: accentColor.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: accentColor.withValues(alpha: 0.7)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _numOrTextInput(
    TextEditingController ctrl,
    String hint,
    bool isNum,
    StateSetter setS, {
    String? prefix,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: isNum ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))] : null,
      textAlign: isNum ? TextAlign.center : TextAlign.left,
      style: GoogleFonts.outfit(
        color: isNum ? CelestialTheme.goldLight : CelestialTheme.textLight,
        fontSize: 11,
        fontWeight: isNum ? FontWeight.w600 : FontWeight.normal,
      ),
      onChanged: (_) => setS(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 10, color: CelestialTheme.textSubtle),
        prefixText: prefix,
        prefixStyle: const TextStyle(fontSize: 10, color: CelestialTheme.goldPrimary),
        filled: true,
        fillColor: isNum
            ? CelestialTheme.goldPrimary.withValues(alpha: 0.06)
            : CelestialTheme.bgSurface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
              color: isNum
                  ? CelestialTheme.goldPrimary.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
              color: isNum
                  ? CelestialTheme.goldPrimary.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.6)),
        ),
      ),
    );
  }

  Widget _unitDropdown(String value, ValueChanged<String?> onChanged) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: CelestialTheme.bgSurface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: CelestialTheme.bgCard,
          style: const TextStyle(color: CelestialTheme.textLight, fontSize: 11),
          isExpanded: true,
          items: kIngredientUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _lineCostBox(double cost) => Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cost > 0
              ? CelestialTheme.emeraldReady.withValues(alpha: 0.08)
              : CelestialTheme.bgSurface,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: cost > 0
                ? CelestialTheme.emeraldReady.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Text(
          cost > 0 ? '₱${cost.toStringAsFixed(2)}' : '—',
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: cost > 0 ? CelestialTheme.emeraldReady : CelestialTheme.textSubtle,
          ),
        ),
      );

  Widget _summaryRow(String label, String value, Color valueColor,
      {bool bold = false, bool large = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: bold ? 11 : 10,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: bold ? CelestialTheme.textLight : CelestialTheme.textMuted,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: large ? 15 : 12,
              fontWeight: bold || large ? FontWeight.bold : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          text,
          style: GoogleFonts.outfit(
              fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      );

  Widget _th(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: CelestialTheme.textMuted,
          letterSpacing: 0.5,
        ),
      );

  Widget _thW2(String text, double width) => SizedBox(
        width: width,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: CelestialTheme.textMuted,
            letterSpacing: 0.5,
          ),
        ),
      );
}

// ── Row data holders ─────────────────────────────────────────────────────────

class _IngRow {
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  String unit;
  final TextEditingController cpuCtrl;

  _IngRow({String name = '', String qty = '', this.unit = 'pcs', String cpu = ''})
      : nameCtrl = TextEditingController(text: name),
        qtyCtrl = TextEditingController(text: qty),
        cpuCtrl = TextEditingController(text: cpu);

  double get lineCost {
    final q = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
    final c = double.tryParse(cpuCtrl.text.trim()) ?? 0.0;
    return q > 0 && c > 0 ? q * c : 0.0;
  }

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    cpuCtrl.dispose();
  }
}

class _MatRow {
  final TextEditingController nameCtrl;
  final TextEditingController costCtrl;

  _MatRow({String name = '', String cost = ''})
      : nameCtrl = TextEditingController(text: name),
        costCtrl = TextEditingController(text: cost);

  double get matCost => double.tryParse(costCtrl.text.trim()) ?? 0.0;

  void dispose() {
    nameCtrl.dispose();
    costCtrl.dispose();
  }
}

// ── KPI card ─────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  final bool smallValue;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    this.smallValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: CelestialTheme.textMuted,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: smallValue ? 13 : 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            sub,
            style: GoogleFonts.outfit(fontSize: 10, color: CelestialTheme.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
