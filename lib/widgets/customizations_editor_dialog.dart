import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/menu_item.dart';
import '../theme/celestial_theme.dart';

class CustomizationsEditorDialog extends StatefulWidget {
  final List<CustomizationGroup> initialGroups;
  final ValueChanged<List<CustomizationGroup>> onSave;

  const CustomizationsEditorDialog({
    super.key,
    required this.initialGroups,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required List<CustomizationGroup> initialGroups,
    required ValueChanged<List<CustomizationGroup>> onSave,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CustomizationsEditorDialog(
        initialGroups: initialGroups,
        onSave: onSave,
      ),
    );
  }

  @override
  State<CustomizationsEditorDialog> createState() => _CustomizationsEditorDialogState();
}

class _CustomizationsEditorDialogState extends State<CustomizationsEditorDialog> {
  late List<CustomizationGroup> _groups;

  @override
  void initState() {
    super.initState();
    // Deep copy the initial groups so we can edit safely
    _groups = widget.initialGroups.map((g) {
      return g.copyWith(
        options: g.options.map((o) => o.copyWith()).toList(),
      );
    }).toList();
  }

  void _addNewGroup() {
    setState(() {
      _groups.add(
        CustomizationGroup(
          id: 'group_${DateTime.now().millisecondsSinceEpoch}',
          title: 'New Option Group',
          options: [],
        ),
      );
    });
  }

  void _editGroup(int groupIndex) {
    _showGroupEditorDialog(groupIndex, _groups[groupIndex]);
  }

  void _deleteGroup(int index) {
    setState(() {
      _groups.removeAt(index);
    });
  }

  Future<void> _showGroupEditorDialog(int groupIndex, CustomizationGroup group) async {
    final titleController = TextEditingController(text: group.title);
    bool isMultiSelect = group.isMultiSelect;
    bool isRequired = group.isRequired;
    
    // Deep copy options for editing
    List<CustomizationOption> tempOptions = group.options.map((o) => o.copyWith()).toList();
    int defaultIndex = group.defaultIndex;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setGroupState) {
            void addOption() {
              setGroupState(() {
                tempOptions.add(const CustomizationOption(name: 'New Option', extraPrice: 0.0));
              });
            }

            return AlertDialog(
              backgroundColor: CelestialTheme.bgSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
              ),
              title: Text('Edit Group: ${group.title}'),
              titleTextStyle: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: CelestialTheme.goldLight,
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        style: TextStyle(color: CelestialTheme.textLight),
                        decoration: InputDecoration(
                          labelText: 'Group Title (e.g. Temperature, Add-ons)',
                          labelStyle: TextStyle(color: CelestialTheme.textMuted),
                          filled: true,
                          fillColor: CelestialTheme.bgCard,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SwitchListTile(
                              title: Text('Allow Multiple Selections', style: TextStyle(color: CelestialTheme.textLight, fontSize: 13)),
                              value: isMultiSelect,
                              activeThumbColor: CelestialTheme.goldPrimary,
                              onChanged: (val) => setGroupState(() => isMultiSelect = val),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: SwitchListTile(
                              title: Text('Required Choice', style: TextStyle(color: CelestialTheme.textLight, fontSize: 13)),
                              value: isRequired,
                              activeThumbColor: CelestialTheme.goldPrimary,
                            onChanged: (val) => setGroupState(() => isRequired = val),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        ],
                      ),
                      Divider(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Options & Prices', style: TextStyle(color: CelestialTheme.textLight, fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: addOption,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Option'),
                            style: TextButton.styleFrom(foregroundColor: CelestialTheme.goldLight),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (tempOptions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('No options added yet.', style: TextStyle(color: CelestialTheme.textMuted, fontStyle: FontStyle.italic)),
                        ),
                      ...List.generate(tempOptions.length, (optIndex) {
                        final opt = tempOptions[optIndex];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: CelestialTheme.bgCard,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              if (!isMultiSelect && isRequired)
                                Radio<int>(
                                  value: optIndex,
                                  groupValue: defaultIndex,
                                  activeColor: CelestialTheme.goldPrimary,
                                  onChanged: (val) {
                                    if (val != null) setGroupState(() => defaultIndex = val);
                                  },
                                ),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: opt.name,
                                  style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    labelText: 'Option Name',
                                    labelStyle: TextStyle(color: CelestialTheme.textMuted, fontSize: 11),
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: (val) => tempOptions[optIndex] = tempOptions[optIndex].copyWith(name: val),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  initialValue: opt.extraPrice == 0 ? '0' : opt.extraPrice.toStringAsFixed(0),
                                  style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    labelText: 'Extra Price',
                                    prefixText: '₱ ',
                                    prefixStyle: TextStyle(color: CelestialTheme.goldLight),
                                    labelStyle: TextStyle(color: CelestialTheme.textMuted, fontSize: 11),
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: (val) {
                                    final price = double.tryParse(val) ?? 0.0;
                                    tempOptions[optIndex] = tempOptions[optIndex].copyWith(extraPrice: price);
                                  },
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 18, color: CelestialTheme.roseAlert),
                                onPressed: () {
                                  setGroupState(() {
                                    tempOptions.removeAt(optIndex);
                                    if (defaultIndex >= tempOptions.length) {
                                      defaultIndex = 0;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _groups[groupIndex] = _groups[groupIndex].copyWith(
                        title: titleController.text.trim(),
                        isMultiSelect: isMultiSelect,
                        isRequired: isRequired,
                        defaultIndex: defaultIndex,
                        options: tempOptions,
                      );
                    });
                    Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CelestialTheme.goldPrimary,
                    foregroundColor: CelestialTheme.bgSurface,
                  ),
                  child: const Text('Save Group', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: CelestialTheme.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
      ),
      title: Row(
        children: [
          Icon(Icons.tune_rounded, color: CelestialTheme.goldPrimary),
          const SizedBox(width: 8),
          Text(
            'Manage Add-ons & Options',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: CelestialTheme.goldLight,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            Text(
              'Customize the options available for this item. Customers will be able to select these choices when ordering.',
              style: TextStyle(color: CelestialTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _groups.isEmpty
                  ? Center(
                      child: Text(
                        'No custom options added yet.',
                        style: TextStyle(color: CelestialTheme.textMuted.withValues(alpha: 0.7)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _groups.length,
                      itemBuilder: (context, index) {
                        final group = _groups[index];
                        return Card(
                          color: CelestialTheme.bgCard,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        group.title,
                                        style: TextStyle(
                                          color: CelestialTheme.goldLight,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.edit, size: 18, color: CelestialTheme.goldPrimary),
                                          onPressed: () => _editGroup(index),
                                          tooltip: 'Edit Group',
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete, size: 18, color: CelestialTheme.roseAlert),
                                          onPressed: () => _deleteGroup(index),
                                          tooltip: 'Delete Group',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${group.options.length} Options • ${group.isMultiSelect ? "Multiple Choice" : "Single Choice"} • ${group.isRequired ? "Required" : "Optional"}',
                                  style: TextStyle(color: CelestialTheme.textMuted, fontSize: 11),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: group.options.map((opt) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: CelestialTheme.bgSurfaceLight,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        '${opt.name}${opt.extraPrice > 0 ? " (+₱${opt.extraPrice.toStringAsFixed(0)})" : ""}',
                                        style: TextStyle(color: CelestialTheme.textLight, fontSize: 11),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addNewGroup,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Add New Option Group'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CelestialTheme.goldLight,
                  side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(_groups);
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: CelestialTheme.goldPrimary,
            foregroundColor: CelestialTheme.bgSurface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Done & Apply', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
