import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import 'item_thumbnail.dart';
import 'price_editor_dialog.dart';

class CustomizationDialog extends StatefulWidget {
  final MenuItem item;
  final Function(int quantity, List<SelectedCustomization> customizations, String? notes) onAddToCart;

  const CustomizationDialog({
    super.key,
    required this.item,
    required this.onAddToCart,
  });

  @override
  State<CustomizationDialog> createState() => _CustomizationDialogState();
}

class _CustomizationDialogState extends State<CustomizationDialog> {
  int _quantity = 1;
  final Map<String, List<CustomizationOption>> _selectedOptions = {};
  bool _isAdding = false;
  late MenuItem _currentItem;

  PosProvider? get _posProvider {
    try {
      return Provider.of<PosProvider>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  MenuItem get _liveItem {
    final provider = _posProvider;
    if (provider != null) {
      try {
        return provider.menuItems.firstWhere(
          (m) => m.id == widget.item.id,
          orElse: () => _currentItem,
        );
      } catch (_) {
        return _currentItem;
      }
    }
    return _currentItem;
  }

  void _notifyOptionUnavailable(CustomizationGroup group, CustomizationOption option) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: CelestialTheme.bgCard,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: CelestialTheme.borderSubtle),
        ),
        action: SnackBarAction(
          label: 'RESTOCK',
          textColor: CelestialTheme.goldPrimary,
          onPressed: () {
            _toggleOptionAvailability(group, option, true);
          },
        ),
        content: Row(
          children: [
            Icon(Icons.do_not_disturb_on_outlined, color: CelestialTheme.roseAlert, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '⚠️ "${option.name}" is currently sold out / not available.',
                style: TextStyle(color: CelestialTheme.textLight, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleOptionAvailability(
    CustomizationGroup group,
    CustomizationOption option, [
    bool? targetState,
    bool applyGlobally = false,
  ]) {
    final newAvail = targetState ?? !option.isAvailable;
    final provider = _posProvider;

    if (provider != null) {
      if (applyGlobally) {
        provider.toggleOptionAvailabilityGlobally(option.name, newAvail);
      } else {
        provider.toggleOptionAvailability(widget.item.id, group.id, option.name, newAvail);
      }
      final updated = provider.menuItems.firstWhere(
        (m) => m.id == widget.item.id,
        orElse: () => _currentItem,
      );
      _currentItem = updated;
    } else {
      // Local fallback for standalone test environments
      final updatedGroups = _currentItem.customizationGroups.map((g) {
        if (g.id != group.id) return g;
        final updatedOptions = g.options.map((o) {
          if (o.name != option.name) return o;
          return o.copyWith(isAvailable: newAvail);
        }).toList();
        return g.copyWith(options: updatedOptions);
      }).toList();
      _currentItem = _currentItem.copyWith(customizationGroups: updatedGroups);
    }

    // Adjust selected options when an option is 86'd or restocked
    if (!newAvail) {
      final currentSelected = _selectedOptions[group.id] ?? [];
      if (group.isMultiSelect) {
        _selectedOptions[group.id] = currentSelected.where((o) => o.name != option.name).toList();
      } else {
        if (currentSelected.any((o) => o.name == option.name)) {
          // Read from _currentItem (already updated above) to avoid stale provider state
          final updatedGroup = _currentItem.customizationGroups.firstWhere(
            (g) => g.id == group.id,
            orElse: () => group,
          );
          final nextAvailable = updatedGroup.options
              .where((o) => o.isAvailable && o.name != option.name)
              .firstOrNull;
          _selectedOptions[group.id] = nextAvailable != null ? [nextAvailable] : [];
        }
      }
    } else {
      final currentSelected = _selectedOptions[group.id] ?? [];
      if (!group.isMultiSelect && currentSelected.isEmpty) {
        _selectedOptions[group.id] = [option.copyWith(isAvailable: true)];
      }
    }

    setState(() {});

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: CelestialTheme.bgCard,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: newAvail ? CelestialTheme.goldPrimary : CelestialTheme.roseAlert,
            width: 1.0,
          ),
        ),
        content: Row(
          children: [
            Icon(
              newAvail ? Icons.check_circle_rounded : Icons.block_rounded,
              color: newAvail ? const Color(0xFF10B981) : CelestialTheme.roseAlert,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                newAvail
                    ? '"${option.name}" is now available in stock.'
                    : '"${option.name}" is now marked sold out.',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupAvailabilitySheet(CustomizationGroup group) {
    bool applyGlobally = false;

    showDialog(
      context: context,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            final liveGroup = _liveItem.customizationGroups.firstWhere(
              (g) => g.id == group.id,
              orElse: () => group,
            );

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                width: 440,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.82,
                ),
                decoration: BoxDecoration(
                  color: CelestialTheme.bgSurface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: CelestialTheme.borderWarm,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.70),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: CelestialTheme.bgCardActive,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _getGroupIcon(liveGroup),
                              size: 18,
                              color: CelestialTheme.goldPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${liveGroup.title} Availability',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Control in-stock & modifier availability',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    color: CelestialTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetCtx),
                            icon: Icon(Icons.close_rounded, color: CelestialTheme.textMuted, size: 20),
                            splashRadius: 18,
                          ),
                        ],
                      ),
                    ),
                    Divider(color: CelestialTheme.borderWarm, height: 1),

                    // Global Switch Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      color: CelestialTheme.bgCard,
                      child: Row(
                        children: [
                          Icon(Icons.public_rounded, size: 16, color: CelestialTheme.goldPrimary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Apply to all menu items',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Update availability cafe-wide across all items',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: CelestialTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: applyGlobally,
                            activeThumbColor: CelestialTheme.goldPrimary,
                            activeTrackColor: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                            inactiveThumbColor: CelestialTheme.textMuted,
                            inactiveTrackColor: CelestialTheme.bgCardActive,
                            onChanged: (val) {
                              setSheetState(() => applyGlobally = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    Divider(color: CelestialTheme.borderWarm, height: 1),

                    // Option List
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: liveGroup.options.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final opt = liveGroup.options[index];
                          final isAvail = opt.isAvailable;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: CelestialTheme.bgCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isAvail
                                    ? CelestialTheme.borderWarm
                                    : CelestialTheme.roseAlert.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        opt.name,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: isAvail ? Colors.white : CelestialTheme.roseAlert,
                                          decoration: isAvail ? null : TextDecoration.lineThrough,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      InkWell(
                                        onTap: () {
                                          final prov = _posProvider;
                                          if (prov == null) return;
                                          PriceEditorDialog.showOptionPriceEditor(
                                            context,
                                            prov,
                                            itemId: widget.item.id,
                                            groupId: liveGroup.id,
                                            groupTitle: liveGroup.title,
                                            option: opt,
                                            defaultApplyGlobally: applyGlobally,
                                            onSaved: () {
                                              setSheetState(() {});
                                              setState(() {});
                                            },
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: opt.extraPrice > 0
                                                ? CelestialTheme.goldPrimary.withValues(alpha: 0.18)
                                                : CelestialTheme.bgCardActive,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: opt.extraPrice > 0
                                                  ? CelestialTheme.goldPrimary.withValues(alpha: 0.5)
                                                  : CelestialTheme.borderWarm,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                opt.extraPrice > 0
                                                    ? '+₱${opt.extraPrice.toStringAsFixed(0)}'
                                                    : '₱0 (Free)',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11,
                                                  color: opt.extraPrice > 0
                                                      ? CelestialTheme.goldPrimary
                                                      : CelestialTheme.textMuted,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(Icons.edit, size: 10, color: CelestialTheme.goldPrimary),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isAvail
                                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                        : CelestialTheme.roseAlert.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isAvail ? 'IN STOCK' : 'NOT AVAILABLE',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      color: isAvail
                                          ? const Color(0xFF10B981)
                                          : CelestialTheme.roseAlert,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Switch.adaptive(
                                  value: isAvail,
                                  activeThumbColor: const Color(0xFF10B981),
                                  activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
                                  inactiveThumbColor: CelestialTheme.roseAlert,
                                  inactiveTrackColor: CelestialTheme.roseAlert.withValues(alpha: 0.25),
                                  onChanged: (newVal) {
                                    _toggleOptionAvailability(
                                      liveGroup,
                                      opt,
                                      newVal,
                                      applyGlobally,
                                    );
                                    setSheetState(() {});
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    Divider(color: CelestialTheme.borderWarm, height: 1),

                    // Bottom Actions
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          if (liveGroup.options.any((o) => !o.isAvailable))
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () {
                                  for (final opt in liveGroup.options) {
                                    if (!opt.isAvailable) {
                                      _toggleOptionAvailability(
                                        liveGroup,
                                        opt,
                                        true,
                                        applyGlobally,
                                      );
                                    }
                                  }
                                  setSheetState(() {});
                                },
                                icon: const Icon(Icons.restore_rounded, size: 16, color: Color(0xFF10B981)),
                                label: Text(
                                  'Restock All',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF10B981),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          if (liveGroup.options.any((o) => !o.isAvailable))
                            const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(sheetCtx),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: CelestialTheme.goldPrimary,
                                foregroundColor: CelestialTheme.isLondon ? Colors.white : CelestialTheme.bgDark,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: Text(
                                'Done',
                                style: GoogleFonts.outfit(
                                  color: CelestialTheme.isLondon ? Colors.white : CelestialTheme.bgDark,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
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
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    // Pre-select default options for single-select groups (skipping unavailable options)
    for (var group in _currentItem.customizationGroups) {
      if (group.options.isNotEmpty) {
        if (!group.isMultiSelect) {
          CustomizationOption? chosen;
          if (group.defaultIndex < group.options.length && group.options[group.defaultIndex].isAvailable) {
            chosen = group.options[group.defaultIndex];
          } else {
            chosen = group.options.firstWhere(
              (o) => o.isAvailable,
              orElse: () => group.options.first,
            );
          }
          _selectedOptions[group.id] = [chosen];
        } else {
          _selectedOptions[group.id] = [];
        }
      }
    }
  }

  double get _currentUnitPrice {
    double total = _liveItem.price;
    _selectedOptions.forEach((groupId, options) {
      for (var opt in options) {
        total += opt.extraPrice;
      }
    });
    return total;
  }

  double get _currentTotalPrice => _currentUnitPrice * _quantity;

  List<SelectedCustomization> _buildCustomizationsList() {
    final list = <SelectedCustomization>[];
    for (var group in _liveItem.customizationGroups) {
      final opts = _selectedOptions[group.id] ?? [];
      for (var opt in opts) {
        list.add(
          SelectedCustomization(
            groupTitle: group.title,
            optionName: opt.name,
            extraPrice: opt.extraPrice,
          ),
        );
      }
    }
    return list;
  }

  bool _isTemperatureGroup(CustomizationGroup group) {
    final id = group.id.toLowerCase();
    final title = group.title.toLowerCase();
    return id.contains('temp') || title.contains('temp');
  }

  bool _isSweetnessGroup(CustomizationGroup group) {
    final id = group.id.toLowerCase();
    final title = group.title.toLowerCase();
    return id.contains('sweet') || title.contains('sweet') || id.contains('sugar') || title.contains('sugar');
  }

  IconData _getGroupIcon(CustomizationGroup group) {
    final id = group.id.toLowerCase();
    final title = group.title.toLowerCase();

    if (_isTemperatureGroup(group)) {
      return Icons.thermostat_rounded;
    }
    if (_isSweetnessGroup(group)) {
      return Icons.water_drop_rounded;
    }
    if (id.contains('size') || title.contains('size') || title.contains('cup')) {
      return Icons.local_cafe_rounded;
    }
    if (id.contains('whip') || title.contains('whip') || title.contains('cream')) {
      return Icons.icecream_rounded;
    }
    if (id.contains('prep') || title.contains('prep') || title.contains('cook')) {
      return Icons.restaurant_rounded;
    }
    if (group.isMultiSelect || id.contains('addon') || title.contains('addon') || title.contains('extra') || title.contains('sinker')) {
      return Icons.auto_awesome_rounded;
    }
    return Icons.tune_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: isMobile ? double.infinity : 480,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * (isMobile ? 0.94 : 0.90),
        ),
        decoration: BoxDecoration(
          color: CelestialTheme.bgSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: CelestialTheme.borderWarm,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.75),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogHeader(isMobile),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ..._liveItem.customizationGroups.map((group) {
                            return _buildGroupSection(group, isMobile);
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Footer
            _buildFooter(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildShowcaseMedia(bool isMobile) {
    return ItemThumbnail(
      item: _liveItem,
      width: double.infinity,
      borderRadius: BorderRadius.zero,
      iconSize: isMobile ? 44 : 54,
    );
  }

  Widget _buildDialogHeader(bool isMobile) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        isMobile ? 14 : 18,
        isMobile ? 14 : 18,
        isMobile ? 14 : 18,
        14,
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: CelestialTheme.borderWarm,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Inset Media Container with floating Close Button
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: isMobile ? 160 : 185,
                decoration: BoxDecoration(
                  color: CelestialTheme.bgSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildShowcaseMedia(isMobile),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.60),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.0,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Item Name
          Text(
            _liveItem.name,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: isMobile ? 20 : 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Price
          Text(
            '₱${_liveItem.price.toStringAsFixed(0)}',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: isMobile ? 17 : 18.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (_liveItem.description.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _liveItem.description.trim(),
              style: GoogleFonts.outfit(
                color: CelestialTheme.textMuted,
                fontSize: isMobile ? 12 : 13,
                height: 1.35,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupHeader({
    required CustomizationGroup group,
    required String title,
    required IconData icon,
    required bool isRequired,
    required bool isMultiSelect,
    int selectedCount = 0,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onLongPress: () => _showGroupAvailabilitySheet(group),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: CelestialTheme.bgCardActive,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: CelestialTheme.goldPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isMultiSelect && selectedCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: CelestialTheme.bgCard,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: CelestialTheme.borderWarm,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '$selectedCount SELECTED',
                    style: GoogleFonts.outfit(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: CelestialTheme.goldPrimary,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showGroupAvailabilitySheet(group),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: CelestialTheme.bgCardHover,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: CelestialTheme.borderWarm, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 11.5, color: CelestialTheme.goldPrimary),
                      const SizedBox(width: 4),
                      Text(
                        'Availability',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: CelestialTheme.creamSoft,
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
    );
  }

  Widget _buildGroupSection(CustomizationGroup group, bool isMobile) {
    if (group.isMultiSelect) {
      return _buildMultiSelectSection(group, isMobile);
    }
    return _buildStandardSection(group, isMobile);
  }

  // Multi-Select Section (Add-ons & Extras Rows)
  Widget _buildMultiSelectSection(CustomizationGroup group, bool isMobile) {
    final selectedList = _selectedOptions[group.id] ?? [];
    final icon = _getGroupIcon(group);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroupHeader(
            group: group,
            title: group.title,
            icon: icon,
            isRequired: group.isRequired,
            isMultiSelect: true,
            selectedCount: selectedList.length,
          ),
          const SizedBox(height: 12),
          Column(
            children: group.options.map((option) {
              final isSelected = selectedList.any((o) => o.name == option.name);
              final isAvailable = option.isAvailable;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: isAvailable
                      ? () {
                          setState(() {
                            final current = _selectedOptions[group.id] ?? [];
                            if (isSelected) {
                              _selectedOptions[group.id] = current.where((o) => o.name != option.name).toList();
                            } else {
                              _selectedOptions[group.id] = [...current, option];
                            }
                          });
                        }
                      : () => _notifyOptionUnavailable(group, option),
                  onLongPress: () => _toggleOptionAvailability(group, option),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: CelestialTheme.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: !isAvailable
                            ? CelestialTheme.roseAlert.withValues(alpha: 0.35)
                            : isSelected
                                ? CelestialTheme.goldPrimary
                                : CelestialTheme.borderWarm,
                        width: isSelected ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? CelestialTheme.goldPrimary : CelestialTheme.bgCardActive,
                            border: Border.all(
                              color: isSelected ? CelestialTheme.goldPrimary : CelestialTheme.borderWarm,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              isSelected ? Icons.check_rounded : Icons.add_rounded,
                              size: 15,
                              color: isSelected
                                  ? (CelestialTheme.isLondon ? Colors.white : CelestialTheme.bgDark)
                                  : CelestialTheme.warmGray,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                option.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: !isAvailable
                                      ? CelestialTheme.roseAlert
                                      : (isSelected ? Colors.white : CelestialTheme.creamSoft),
                                  decoration: !isAvailable ? TextDecoration.lineThrough : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (!isAvailable) ...[
                                const SizedBox(height: 3),
                                InkWell(
                                  onTap: () => _toggleOptionAvailability(group, option, true),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: CelestialTheme.roseAlert.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: CelestialTheme.roseAlert.withValues(alpha: 0.45),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      'Not Available',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: CelestialTheme.roseAlert,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (option.extraPrice > 0) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              final posProvider = _posProvider;
                              if (posProvider == null) return;
                              PriceEditorDialog.showOptionPriceEditor(
                                context,
                                posProvider,
                                itemId: widget.item.id,
                                groupId: group.id,
                                groupTitle: group.title,
                                option: option,
                                onSaved: () => setState(() {}),
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: _buildPriceBadge(option.extraPrice, isSelected),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBadge(double extraPrice, bool isSelected) {
    final isPositive = extraPrice > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? CelestialTheme.goldPrimary.withValues(alpha: 0.22)
            : CelestialTheme.bgCardActive,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected
              ? CelestialTheme.goldPrimary
              : CelestialTheme.borderWarm,
          width: 0.8,
        ),
      ),
      child: Text(
        isPositive
            ? '+₱${extraPrice.toStringAsFixed(0)}'
            : '-₱${(-extraPrice).toStringAsFixed(0)}',
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isSelected ? CelestialTheme.goldPrimary : CelestialTheme.textMuted,
        ),
      ),
    );
  }

  // Standard Single-Select Section (2-Column Grid matching Screenshot)
  Widget _buildStandardSection(CustomizationGroup group, bool isMobile) {
    final selectedList = _selectedOptions[group.id] ?? [];
    final icon = _getGroupIcon(group);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroupHeader(
            group: group,
            title: group.title,
            icon: icon,
            isRequired: group.isRequired,
            isMultiSelect: false,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isSingle = group.options.length == 1;
              final hasLongText = group.options.any((o) {
                final name = o.name.trim();
                return name.length > 11 ||
                    (name.length > 7 && o.extraPrice != 0) ||
                    name.contains('(') ||
                    name.contains('/') ||
                    name.split(RegExp(r'\s+')).length > 2;
              });
              final useFullWidthRows = isSingle || group.options.length > 4 || hasLongText;
              const spacing = 10.0;
              final itemWidth = useFullWidthRows
                  ? constraints.maxWidth
                  : (constraints.maxWidth - spacing) / 2;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: group.options.map((option) {
                  final isSelected = selectedList.any((o) => o.name == option.name);
                  return SizedBox(
                    width: itemWidth,
                    child: _buildStandardChip(
                      group: group,
                      option: option,
                      isSelected: isSelected,
                      isMobile: isMobile,
                      isFullWidth: useFullWidthRows,
                      onTap: () {
                        setState(() {
                          _selectedOptions[group.id] = [option];
                        });
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStandardChip({
    required CustomizationGroup group,
    required CustomizationOption option,
    required bool isSelected,
    required bool isMobile,
    bool isFullWidth = false,
    required VoidCallback onTap,
  }) {
    final isAvailable = option.isAvailable;

    return InkWell(
      onTap: isAvailable ? onTap : () => _notifyOptionUnavailable(group, option),
      onLongPress: () => _toggleOptionAvailability(group, option),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: isFullWidth ? 14 : (isMobile ? 10 : 12),
          vertical: !isAvailable ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: !isAvailable
                ? CelestialTheme.roseAlert.withValues(alpha: 0.35)
                : isSelected
                    ? CelestialTheme.goldPrimary
                    : CelestialTheme.borderWarm,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              !isAvailable
                  ? Icons.block_rounded
                  : isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
              size: 18,
              color: !isAvailable
                  ? CelestialTheme.roseAlert.withValues(alpha: 0.7)
                  : isSelected
                      ? CelestialTheme.goldPrimary
                      : CelestialTheme.warmGray,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.name,
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: !isAvailable
                                ? CelestialTheme.roseAlert
                                : (isSelected ? Colors.white : CelestialTheme.creamSoft),
                            decoration: !isAvailable ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (option.extraPrice != 0) ...[
                        SizedBox(width: isFullWidth ? 8 : 4),
                        InkWell(
                          onTap: () {
                            final posProvider = _posProvider;
                            if (posProvider == null) return;
                            PriceEditorDialog.showOptionPriceEditor(
                              context,
                              posProvider,
                              itemId: widget.item.id,
                              groupId: group.id,
                              groupTitle: group.title,
                              option: option,
                              onSaved: () => setState(() {}),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: _buildPriceBadge(option.extraPrice, isSelected),
                        ),
                      ],
                    ],
                  ),
                  if (!isAvailable) ...[
                    const SizedBox(height: 3),
                    InkWell(
                      onTap: () => _toggleOptionAvailability(group, option, true),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: CelestialTheme.roseAlert.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: CelestialTheme.roseAlert.withValues(alpha: 0.45),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'Not Available',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.roseAlert,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 18,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: CelestialTheme.bgSurface,
        border: Border(
          top: BorderSide(color: CelestialTheme.borderWarm, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // Quantity Stepper Pill
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: CelestialTheme.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: CelestialTheme.borderWarm,
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('customization_qty_minus'),
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                  icon: const Icon(Icons.remove_rounded, size: 18),
                  color: CelestialTheme.goldPrimary,
                  disabledColor: CelestialTheme.goldPrimary.withValues(alpha: 0.3),
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '$_quantity',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('customization_qty_plus'),
                  onPressed: () => setState(() => _quantity++),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  color: CelestialTheme.goldPrimary,
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Dynamic Theme Add to Order Button
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('customization_add_to_cart_btn'),
                onTap: _isAdding
                    ? null
                    : () async {
                        setState(() => _isAdding = true);
                        await Future.delayed(const Duration(milliseconds: 160));
                        final customs = _buildCustomizationsList();
                        widget.onAddToCart(_quantity, customs, null);
                        if (mounted) Navigator.pop(context);
                      },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: CelestialTheme.goldPrimary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isAdding
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: CelestialTheme.primaryBtnText,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 20,
                                color: CelestialTheme.primaryBtnText,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _quantity > 1
                                      ? 'Add $_quantity to Order • ₱${_currentTotalPrice.toStringAsFixed(0)}'
                                      : 'Add to Order • ₱${_currentTotalPrice.toStringAsFixed(0)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: isMobile ? 15 : 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                    color: CelestialTheme.primaryBtnText,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}