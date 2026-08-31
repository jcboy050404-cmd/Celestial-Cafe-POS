import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../theme/celestial_theme.dart';

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
  final TextEditingController _notesController = TextEditingController();
  final Map<String, List<CustomizationOption>> _selectedOptions = {};

  @override
  void initState() {
    super.initState();
    // Pre-select default options for required groups
    for (var group in widget.item.customizationGroups) {
      if (group.options.isNotEmpty) {
        if (!group.isMultiSelect) {
          final defIdx = (group.defaultIndex < group.options.length) ? group.defaultIndex : 0;
          _selectedOptions[group.id] = [group.options[defIdx]];
        } else {
          _selectedOptions[group.id] = [];
        }
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _currentUnitPrice {
    double total = widget.item.price;
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
    for (var group in widget.item.customizationGroups) {
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

  Widget _buildItemMedia(bool isMobile) {
    final bool hasBase64 = widget.item.imageBase64 != null && widget.item.imageBase64!.isNotEmpty;
    final bool hasFile = widget.item.imagePath != null && widget.item.imagePath!.isNotEmpty && File(widget.item.imagePath!).existsSync();

    if (hasBase64 || hasFile) {
      return Container(
        width: isMobile ? 48 : 56,
        height: isMobile ? 48 : 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: hasBase64
              ? Image.memory(
                  base64Decode(widget.item.imageBase64!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(child: Text(widget.item.icon, style: TextStyle(fontSize: isMobile ? 20 : 24))),
                )
              : Image.file(
                  File(widget.item.imagePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(child: Text(widget.item.icon, style: TextStyle(fontSize: isMobile ? 20 : 24))),
                ),
        ),
      );
    }

    return Container(
      width: isMobile ? 42 : 48,
      height: isMobile ? 42 : 48,
      decoration: BoxDecoration(
        gradient: CelestialTheme.brownGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CelestialTheme.goldPrimary.withValues(alpha: 0.3),
        ),
      ),
      child: Center(
        child: Text(
          widget.item.icon,
          style: TextStyle(fontSize: isMobile ? 20 : 24),
        ),
      ),
    );
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
        width: isMobile ? double.infinity : 540,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * (isMobile ? 0.92 : 0.88),
        ),
        decoration: BoxDecoration(
          color: CelestialTheme.bgSurface,
          borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
          border: Border.all(
            color: CelestialTheme.goldPrimary.withValues(alpha: 0.3),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: CelestialTheme.goldPrimary.withValues(alpha: 0.08),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with Item Info & Close button
            _buildDialogHeader(isMobile),

            const Divider(height: 1),

            // Scrollable Customization Options
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Render Customization Groups
                    ...widget.item.customizationGroups.map((group) {
                      return _buildGroupSection(group, isMobile);
                    }),

                    const SizedBox(height: 12),

                    // Special Notes Input
                    Text(
                      'Special Order Notes / Instructions',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CelestialTheme.textLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _notesController,
                      style: const TextStyle(fontSize: 13, color: CelestialTheme.textLight),
                      decoration: InputDecoration(
                        hintText: 'e.g. Less ice, extra dip, sauce on the side...',
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

            // Bottom Footer with Quantity & Add Button
            _buildFooter(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(isMobile ? 20 : 24)),
      ),
      child: Row(
        children: [
          _buildItemMedia(isMobile),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.name,
                  style: GoogleFonts.outfit(
                    color: CelestialTheme.textLight,
                    fontSize: isMobile ? 15 : 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.item.description,
                  style: GoogleFonts.outfit(
                    color: CelestialTheme.textMuted,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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

  Widget _buildGroupSection(CustomizationGroup group, bool isMobile) {
    final selectedList = _selectedOptions[group.id] ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                group.title,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CelestialTheme.goldLight,
                ),
              ),
              if (group.isRequired) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: CelestialTheme.brownWarm.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: CelestialTheme.goldLight,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.options.map((option) {
              final isSelected = selectedList.any((o) => o.name == option.name);

              return InkWell(
                onTap: () {
                  setState(() {
                    if (group.isMultiSelect) {
                      if (isSelected) {
                        selectedList.removeWhere((o) => o.name == option.name);
                      } else {
                        selectedList.add(option);
                      }
                      _selectedOptions[group.id] = selectedList;
                    } else {
                      _selectedOptions[group.id] = [option];
                    }
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 14,
                    vertical: isMobile ? 8 : 10,
                  ),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        group.isMultiSelect
                            ? (isSelected
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded)
                            : (isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded),
                        size: 15,
                        color: isSelected
                            ? CelestialTheme.goldPrimary
                            : CelestialTheme.textSubtle,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        option.name,
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? CelestialTheme.textLight
                              : CelestialTheme.textMuted,
                        ),
                      ),
                      if (option.extraPrice != 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          option.extraPrice > 0
                              ? '+ ₱${option.extraPrice.toStringAsFixed(0)}'
                              : '- ₱${(-option.extraPrice).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? CelestialTheme.goldLight
                                : CelestialTheme.brownCaramel,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(isMobile ? 20 : 24)),
      ),
      child: Row(
        children: [
          // Quantity Selector
          Container(
            height: isMobile ? 42 : 46,
            decoration: BoxDecoration(
              color: CelestialTheme.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                  icon: const Icon(Icons.remove_rounded, size: 16),
                  color: CelestialTheme.goldPrimary,
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: isMobile ? 32 : 38, minHeight: 32),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '$_quantity',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: CelestialTheme.textLight,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _quantity++),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  color: CelestialTheme.goldPrimary,
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: isMobile ? 32 : 38, minHeight: 32),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Total Price & Add to Order CTA
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                final customs = _buildCustomizationsList();
                final notes = _notesController.text.trim().isNotEmpty
                    ? _notesController.text.trim()
                    : null;
                widget.onAddToCart(_quantity, customs, notes);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: CelestialTheme.goldPrimary,
                foregroundColor: CelestialTheme.bgDark,
                elevation: 6,
                shadowColor: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Add • ₱${_currentTotalPrice.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
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
