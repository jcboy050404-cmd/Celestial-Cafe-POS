import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/app_feature.dart';
import '../models/order.dart';
import '../services/auth_service.dart';
import '../services/cloud_backup_service.dart';
import '../theme/celestial_theme.dart';
import 'create_pin_dialog.dart';

class AdminManagementDialog extends StatefulWidget {
  const AdminManagementDialog({super.key});

  static Future<void> show(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (!auth.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: CelestialTheme.bgCard,
          content: Text('Access Denied: Store administrator privileges required.'),
        ),
      );
      return Future.value();
    }
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => const AdminManagementDialog(),
    );
  }

  @override
  State<AdminManagementDialog> createState() => _AdminManagementDialogState();
}

class _AdminManagementDialogState extends State<AdminManagementDialog> {
  String _searchQuery = '';
  String _tierFilter = 'all'; // 'all', 'trial', 'pro'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final auth = Provider.of<AuthService>(context, listen: false);
        auth.syncManagedAccountsFromCloud();
      }
    });
  }

  void _showClientSalesHistoryDialog(BuildContext context, AppUser account) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => _ClientSalesHistoryDialog(account: account),
    );
  }

  void _showCustomTrialDialog(BuildContext context, AuthService auth, AppUser account) {
    final initialDays = account.effectiveTrialDays(auth.defaultTrialDays);
    final daysController = TextEditingController(text: initialDays.toString());
    bool resetStartDate = account.isTrialExpired;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final currentInput = int.tryParse(daysController.text.trim()) ?? initialDays;
          final elapsed = DateTime.now().difference(account.trialStartDate).inDays;
          final previewRemaining = resetStartDate || account.isTrialExpired || elapsed >= currentInput
              ? currentInput
              : (currentInput - elapsed).clamp(0, currentInput);

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: CelestialTheme.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.edit_calendar_rounded,
                                  color: CelestialTheme.goldLight,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Custom Trial Duration',
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: CelestialTheme.textLight,
                                      ),
                                    ),
                                    Text(
                                      account.email,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: CelestialTheme.textMuted,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded, color: CelestialTheme.textMuted, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),

                  const SizedBox(height: 18),

                  Text(
                    'INPUT TRIAL DAYS',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: CelestialTheme.goldLight,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Custom Numerical Input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: daysController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                          style: GoogleFonts.robotoMono(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.textLight,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: CelestialTheme.bgCard,
                            hintText: 'e.g. 30',
                            hintStyle: TextStyle(color: CelestialTheme.textMuted),
                            prefixIcon: Icon(Icons.hourglass_top_rounded, color: CelestialTheme.goldPrimary, size: 20),
                            suffixText: 'DAYS',
                            suffixStyle: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: CelestialTheme.goldLight,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: CelestialTheme.borderWarm),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: CelestialTheme.borderWarm),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: CelestialTheme.goldPrimary, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Quick Preset Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [0, 7, 14, 30, 45, 60, 90].map((days) {
                      final isZero = days == 0;
                      final isSelected = currentInput == days;
                      return ActionChip(
                        label: Text(isZero ? '0 Days (End Trial)' : '$days Days'),
                        backgroundColor: isSelected
                            ? (isZero
                                ? CelestialTheme.roseAlert.withValues(alpha: 0.25)
                                : CelestialTheme.goldPrimary.withValues(alpha: 0.25))
                            : CelestialTheme.bgCard,
                        labelStyle: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? (isZero ? CelestialTheme.roseAlert : CelestialTheme.goldLight)
                              : CelestialTheme.textLight,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? (isZero ? CelestialTheme.roseAlert : CelestialTheme.goldPrimary)
                              : (isZero
                                  ? CelestialTheme.roseAlert.withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.08)),
                        ),
                        onPressed: () {
                          daysController.text = days.toString();
                          setDialogState(() {});
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // Reset Start Date Switch (Only relevant if assigning >0 days)
                  if (currentInput > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reset Trial Start to Today',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: CelestialTheme.textLight,
                                  ),
                                ),
                                Text(
                                  'Gives full fresh countdown starting right now',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: CelestialTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: resetStartDate,
                            activeTrackColor: CelestialTheme.goldPrimary,
                            onChanged: (val) => setDialogState(() => resetStartDate = val),
                          ),
                        ],
                      ),
                    ),

                  // Live Calculation Preview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: currentInput == 0
                          ? CelestialTheme.roseAlert.withValues(alpha: 0.12)
                          : CelestialTheme.goldPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: currentInput == 0
                            ? CelestialTheme.roseAlert.withValues(alpha: 0.45)
                            : CelestialTheme.goldPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          currentInput == 0 ? Icons.timer_off_rounded : Icons.sync_rounded,
                          color: currentInput == 0 ? CelestialTheme.roseAlert : CelestialTheme.goldLight,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currentInput == 0
                                ? '⚠ Station trial will immediately conclude (0 Days remaining). User station will prompt Contact Developer popup and block checkout.'
                                : (resetStartDate || account.isTrialExpired
                                    ? '✓ Full $currentInput days countdown will start fresh from today.'
                                    : '✓ $previewRemaining of $currentInput days will remain ($elapsed days elapsed).'),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: currentInput == 0 ? CelestialTheme.roseAlert : CelestialTheme.goldLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.outfit(color: CelestialTheme.textMuted),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final parsedDays = int.tryParse(daysController.text.trim()) ?? initialDays;
                          await auth.updateAccountCustomTrial(
                            account.uid,
                            parsedDays,
                            resetStartDate: parsedDays > 0 && (resetStartDate || account.isTrialExpired),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  parsedDays == 0
                                      ? 'Trial concluded (0 days) for ${account.email}. Contact Developer prompt active.'
                                      : 'Trial synced: $parsedDays days applied to ${account.email}',
                                ),
                                backgroundColor: parsedDays == 0 ? CelestialTheme.roseAlert : CelestialTheme.bgCard,
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          currentInput == 0 ? Icons.timer_off_rounded : Icons.check_rounded,
                          size: 16,
                          color: currentInput == 0 ? Colors.white : CelestialTheme.primaryBtnText,
                        ),
                        label: Text(
                          currentInput == 0 ? 'End Station Trial (0 Days)' : 'Apply Trial Days',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: currentInput == 0 ? CelestialTheme.roseAlert : CelestialTheme.goldPrimary,
                          foregroundColor: currentInput == 0 ? Colors.white : CelestialTheme.primaryBtnText,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        },
      ),
    );
  }

  void _showAccountFeaturesDialog(BuildContext context, AuthService auth, AppUser account) {
    List<String> selectedDisabled = List<String>.from(account.disabledFeatures);
    final isAdminAccount = account.isAdmin;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isFeatureActive(String key) {
            if (isAdminAccount) return true;
            return !selectedDisabled.contains(key);
          }

          void toggleFeature(String key, bool enabled) {
            if (isAdminAccount) return;
            setDialogState(() {
              if (enabled) {
                selectedDisabled.remove(key);
              } else {
                if (!selectedDisabled.contains(key)) {
                  selectedDisabled.add(key);
                }
              }
            });
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: CelestialTheme.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  color: CelestialTheme.goldLight,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Station Features & Permissions',
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: CelestialTheme.textLight,
                                      ),
                                    ),
                                    Text(
                                      account.email,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: CelestialTheme.textMuted,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded, color: CelestialTheme.textMuted, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Admin Notice
                    if (isAdminAccount)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shield_rounded, color: CelestialTheme.goldLight, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Store Administrator: Admin accounts permanently retain full access to all features (Food Costing, Analytics, Menu, History & Settings).',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: CelestialTheme.goldLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (!isAdminAccount) ...[
                      Text(
                        'Customize which tabs and modules this Gmail/station account can access. Disabled features will not appear on their screen.',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: CelestialTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Quick Preset Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Text(
                              'Presets:',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: CelestialTheme.textLight,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ActionChip(
                              label: Text('Full Access', style: GoogleFonts.outfit(fontSize: 10.5)),
                              backgroundColor: selectedDisabled.isEmpty ? CelestialTheme.goldPrimary.withValues(alpha: 0.25) : CelestialTheme.bgCard,
                              labelStyle: GoogleFonts.outfit(
                                color: selectedDisabled.isEmpty ? CelestialTheme.goldLight : CelestialTheme.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                              side: BorderSide(color: selectedDisabled.isEmpty ? CelestialTheme.goldPrimary : Colors.white12),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              onPressed: () {
                                setDialogState(() {
                                  selectedDisabled.clear();
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                            ActionChip(
                              label: Text('Cashier Only', style: GoogleFonts.outfit(fontSize: 10.5)),
                              backgroundColor: CelestialTheme.bgCard,
                              labelStyle: GoogleFonts.outfit(color: CelestialTheme.textMuted, fontWeight: FontWeight.w600),
                              side: const BorderSide(color: Colors.white12),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              onPressed: () {
                                setDialogState(() {
                                  selectedDisabled = [
                                    AppFeature.foodCosting,
                                    AppFeature.analytics,
                                    AppFeature.storeSettings,
                                    AppFeature.inventory,
                                  ];
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                            ActionChip(
                              label: Text('Kitchen Only', style: GoogleFonts.outfit(fontSize: 10.5)),
                              backgroundColor: CelestialTheme.bgCard,
                              labelStyle: GoogleFonts.outfit(color: CelestialTheme.textMuted, fontWeight: FontWeight.w600),
                              side: const BorderSide(color: Colors.white12),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              onPressed: () {
                                setDialogState(() {
                                  selectedDisabled = [
                                    AppFeature.foodCosting,
                                    AppFeature.analytics,
                                    AppFeature.storeSettings,
                                    AppFeature.orderHistory,
                                  ];
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Feature List
                    ...AppFeature.allFeatures.map((feat) {
                      final isEnabled = isFeatureActive(feat.key);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isEnabled
                              ? CelestialTheme.bgCard
                              : Colors.red.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isEnabled
                                ? (isAdminAccount ? CelestialTheme.goldPrimary.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08))
                                : CelestialTheme.roseAlert.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isEnabled
                                    ? CelestialTheme.goldPrimary.withValues(alpha: 0.15)
                                    : CelestialTheme.roseAlert.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                feat.icon,
                                color: isEnabled ? CelestialTheme.goldLight : CelestialTheme.roseAlert,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        feat.title,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isEnabled ? CelestialTheme.textLight : CelestialTheme.textMuted,
                                        ),
                                      ),
                                      if (!isEnabled) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: CelestialTheme.roseAlert.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: CelestialTheme.roseAlert.withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.lock_rounded, size: 7.5, color: CelestialTheme.roseAlert),
                                              const SizedBox(width: 3),
                                              Text(
                                                'LOCKED',
                                                style: TextStyle(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: CelestialTheme.roseAlert,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    feat.description,
                                    style: GoogleFonts.outfit(
                                      fontSize: 10.5,
                                      color: CelestialTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: isEnabled,
                              activeTrackColor: CelestialTheme.goldPrimary,
                              activeThumbColor: Colors.white,
                              inactiveTrackColor: CelestialTheme.bgDark,
                              inactiveThumbColor: CelestialTheme.textMuted,
                              onChanged: isAdminAccount
                                  ? null
                                  : (val) => toggleFeature(feat.key, val),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 16),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Close', style: GoogleFonts.outfit(color: CelestialTheme.textMuted)),
                        ),
                        if (!isAdminAccount) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await auth.updateAccountDisabledFeatures(account.uid, selectedDisabled);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Permissions updated for ${account.email}'),
                                    backgroundColor: CelestialTheme.bgCard,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: Text(
                              'Save Permissions',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CelestialTheme.goldPrimary,
                              foregroundColor: CelestialTheme.primaryBtnText,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context, AuthService auth) {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final daysController = TextEditingController(text: auth.defaultTrialDays.toString());
    SubscriptionTier tier = SubscriptionTier.trial;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: CelestialTheme.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5), width: 1.2),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Add Managed Station / Terminal',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.textLight,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded, color: CelestialTheme.textMuted, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Terminal Gmail / Email',
                      labelStyle: TextStyle(color: CelestialTheme.textMuted),
                      prefixIcon: Icon(Icons.email_outlined, color: CelestialTheme.goldPrimary, size: 18),
                      filled: true,
                      fillColor: CelestialTheme.bgCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Station Name (e.g. Patio POS)',
                      labelStyle: TextStyle(color: CelestialTheme.textMuted),
                      prefixIcon: Icon(Icons.badge_outlined, color: CelestialTheme.goldPrimary, size: 18),
                      filled: true,
                      fillColor: CelestialTheme.bgCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<SubscriptionTier>(
                          initialValue: tier,
                          dropdownColor: CelestialTheme.bgCard,
                          decoration: InputDecoration(
                            labelText: 'License Tier',
                            labelStyle: TextStyle(color: CelestialTheme.textMuted),
                            filled: true,
                            fillColor: CelestialTheme.bgCard,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: SubscriptionTier.trial,
                              child: Text('Trial License', style: TextStyle(color: CelestialTheme.amberBrewing)),
                            ),
                            DropdownMenuItem(
                              value: SubscriptionTier.pro,
                              child: Text('Pro License', style: TextStyle(color: CelestialTheme.goldLight)),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => tier = val);
                          },
                        ),
                      ),
                      if (tier == SubscriptionTier.trial) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: daysController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Trial Days',
                              labelStyle: TextStyle(color: CelestialTheme.textMuted),
                              suffixText: 'd',
                              filled: true,
                              fillColor: CelestialTheme.bgCard,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Cancel', style: GoogleFonts.outfit(color: CelestialTheme.textMuted)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final email = emailController.text.trim();
                          if (email.isEmpty) return;
                          final name = nameController.text.trim();
                          final days = int.tryParse(daysController.text.trim()) ?? auth.defaultTrialDays;
                          await auth.addManagedAccount(
                            email: email,
                            displayName: name.isEmpty ? email.split('@').first : name,
                            tier: tier,
                            trialDays: days,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CelestialTheme.goldPrimary,
                          foregroundColor: CelestialTheme.primaryBtnText,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Add Station'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        },
      ),
    );
  }

  void _showAddAdminDialog(BuildContext context, AuthService auth) {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: CelestialTheme.bgSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Authorize New Admin Gmail',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Users logging in with this Gmail address will have full admin rights.',
                  style: GoogleFonts.outfit(fontSize: 12, color: CelestialTheme.textMuted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. manager.celestial@gmail.com',
                    hintStyle: TextStyle(color: CelestialTheme.textMuted),
                    filled: true,
                    fillColor: CelestialTheme.bgCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel', style: GoogleFonts.outfit(color: CelestialTheme.textMuted)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final email = emailController.text.trim();
                        if (email.isNotEmpty) {
                          await auth.addAdminEmail(email);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CelestialTheme.goldPrimary,
                        foregroundColor: CelestialTheme.primaryBtnText,
                      ),
                      child: const Text('Authorize Admin'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGlobalDefaultTrialDialog(BuildContext context, AuthService auth) {
    final controller = TextEditingController(text: auth.defaultTrialDays.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: CelestialTheme.bgSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5), width: 1.2),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 28, offset: const Offset(0, 10))],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.tune_rounded, color: CelestialTheme.goldLight, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'System Trial Duration',
                            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                          ),
                          Text(
                            'Admin-controlled · Applies to all new sign-ups',
                            style: GoogleFonts.outfit(fontSize: 10, color: CelestialTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: CelestialTheme.goldLight),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Users cannot modify their own trial duration. Only administrators can configure this value.',
                          style: GoogleFonts.outfit(fontSize: 10.5, color: CelestialTheme.goldLight),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.robotoMono(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: CelestialTheme.bgCard,
                    suffixText: 'DAYS',
                    suffixStyle: GoogleFonts.outfit(color: CelestialTheme.textMuted, fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: CelestialTheme.goldPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Quick preset chips
                Text(
                  'QUICK PRESETS',
                  style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: CelestialTheme.textMuted),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [7, 14, 30, 60, 90, 180].map((d) {
                    final isSelected = controller.text == d.toString();
                    return GestureDetector(
                      onTap: () => setDialogState(() => controller.text = d.toString()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected ? CelestialTheme.goldPrimary.withValues(alpha: 0.2) : CelestialTheme.bgCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? CelestialTheme.goldPrimary : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          '$d Days',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? CelestialTheme.goldLight : CelestialTheme.textMuted,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel', style: GoogleFonts.outfit(color: CelestialTheme.textMuted)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final val = int.tryParse(controller.text.trim()) ?? auth.defaultTrialDays;
                        await auth.setDefaultTrialDays(val);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: CelestialTheme.bgCard,
                              content: Text('Default trial duration set to $val days for all new accounts.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: Text('Save Default', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CelestialTheme.goldPrimary,
                        foregroundColor: CelestialTheme.primaryBtnText,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    if (!auth.isAdmin) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: CelestialTheme.bgSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CelestialTheme.roseAlert.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gpp_bad_rounded, color: CelestialTheme.roseAlert, size: 48),
              const SizedBox(height: 14),
              Text(
                'Access Restricted',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Only authorized store administrators can access the admin license manager and modify station accounts.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 12.5, color: CelestialTheme.textMuted, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CelestialTheme.bgCard,
                  foregroundColor: CelestialTheme.textLight,
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 700;

    final accounts = auth.managedAccounts.where((acc) {
      final matchesSearch = acc.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          acc.displayName.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;
      if (_tierFilter == 'trial') return acc.tier == SubscriptionTier.trial;
      if (_tierFilter == 'pro') return acc.tier == SubscriptionTier.pro;
      return true;
    }).toList();

    final totalCount = auth.managedAccounts.length;
    final proCount = auth.managedAccounts.where((a) => a.isPro).length;
    final trialCount = auth.managedAccounts.where((a) => !a.isPro && !a.isTrialExpired).length;
    final expiredCount = auth.managedAccounts.where((a) => a.isTrialExpired).length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 36,
        vertical: isMobile ? 12 : 32,
      ),
      child: Container(
        width: isMobile ? double.infinity : 880,
        height: isMobile ? size.height * 0.94 : 680,
        decoration: BoxDecoration(
          color: CelestialTheme.bgSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
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
        child: Column(
          children: [
            // Top Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: CelestialTheme.bgCard.withValues(alpha: 0.6),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.admin_panel_settings_rounded, color: CelestialTheme.goldLight, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'ADMIN LICENSE & ACCOUNT MANAGER',
                                  style: GoogleFonts.outfit(
                                    fontSize: isMobile ? 13 : 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: isMobile ? 0.5 : 1.0,
                                    color: CelestialTheme.textLight,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: CelestialTheme.goldPrimary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'MASTER',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.goldLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          isMobile
                              ? 'Manage POS terminal subscriptions & trials'
                              : 'Manage POS terminal subscriptions, toggle Pro/Trial, and set custom trial days',
                          style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: CelestialTheme.textMuted, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),

            // Overview Metric Cards
            Padding(
              padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, isMobile ? 12 : 16, isMobile ? 12 : 20, isMobile ? 8 : 10),
              child: isMobile
                  ? Column(
                      children: [
                        Row(
                          children: [
                            _buildMetricCard(label: 'Total Stations', value: '$totalCount', icon: Icons.point_of_sale_rounded, color: CelestialTheme.goldLight),
                            const SizedBox(width: 8),
                            _buildMetricCard(label: 'Pro Enterprise', value: '$proCount', icon: Icons.verified_rounded, color: CelestialTheme.emeraldReady),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildMetricCard(label: 'Active Trials', value: '$trialCount', icon: Icons.hourglass_bottom_rounded, color: CelestialTheme.amberBrewing),
                            const SizedBox(width: 8),
                            _buildMetricCard(label: 'Expired', value: '$expiredCount', icon: Icons.warning_amber_rounded, color: CelestialTheme.roseAlert),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        _buildMetricCard(label: 'Total Stations', value: '$totalCount', icon: Icons.point_of_sale_rounded, color: CelestialTheme.goldLight),
                        const SizedBox(width: 10),
                        _buildMetricCard(label: 'Pro Enterprise', value: '$proCount', icon: Icons.verified_rounded, color: CelestialTheme.emeraldReady),
                        const SizedBox(width: 10),
                        _buildMetricCard(label: 'Active Trials', value: '$trialCount', icon: Icons.hourglass_bottom_rounded, color: CelestialTheme.amberBrewing),
                        const SizedBox(width: 10),
                        _buildMetricCard(label: 'Expired', value: '$expiredCount', icon: Icons.warning_amber_rounded, color: CelestialTheme.roseAlert),
                      ],
                    ),
            ),

            // Global Config Strip
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 4),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: isMobile ? 8 : 8),
                decoration: BoxDecoration(
                  color: CelestialTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: isMobile
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: InkWell(
                              onTap: () => _showGlobalDefaultTrialDialog(context, auth),
                              borderRadius: BorderRadius.circular(6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.tune_rounded, size: 14, color: CelestialTheme.goldLight),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Default: ${auth.defaultTrialDays}d',
                                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: CelestialTheme.textLight),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Edit',
                                    style: GoogleFonts.outfit(fontSize: 10.5, color: CelestialTheme.goldLight, decoration: TextDecoration.underline),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Flexible(
                            child: TextButton.icon(
                              onPressed: () => _showAddAdminDialog(context, auth),
                              icon: Icon(Icons.person_add_alt_1_rounded, size: 14, color: CelestialTheme.goldLight),
                              label: Text(
                                '+ Admin Gmail',
                                style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w600, color: CelestialTheme.goldLight),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.tune_rounded, size: 16, color: CelestialTheme.goldLight),
                              const SizedBox(width: 8),
                              Text(
                                'Default Trial: ${auth.defaultTrialDays} Days',
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: CelestialTheme.textLight),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _showGlobalDefaultTrialDialog(context, auth),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text(
                                    'Change',
                                    style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.goldLight, decoration: TextDecoration.underline),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () => _showAddAdminDialog(context, auth),
                            icon: Icon(Icons.person_add_alt_1_rounded, size: 15, color: CelestialTheme.goldLight),
                            label: Text(
                              '+ Authorize Admin Gmail',
                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: CelestialTheme.goldLight),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // Filter & Search Controls
            Padding(
              padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, 8, isMobile ? 12 : 20, 8),
              child: isMobile
                  ? Column(
                      children: [
                        TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search by terminal email or name...',
                            hintStyle: TextStyle(color: CelestialTheme.textMuted, fontSize: 12),
                            prefixIcon: Icon(Icons.search_rounded, size: 18, color: CelestialTheme.textMuted),
                            filled: true,
                            fillColor: CelestialTheme.bgCard,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: CelestialTheme.borderSubtle),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: CelestialTheme.borderSubtle),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: CelestialTheme.goldPrimary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: CelestialTheme.bgCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: CelestialTheme.borderSubtle),
                                ),
                                child: Row(
                                  children: [
                                    _buildFilterButton('All', 'all', isExpanded: true),
                                    _buildFilterButton('Trial', 'trial', isExpanded: true),
                                    _buildFilterButton('Pro', 'pro', isExpanded: true),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: 'Sync Cloud Accounts',
                              onPressed: auth.isSyncingCloudAccounts
                                  ? null
                                  : () async {
                                      final ok = await auth.syncManagedAccountsFromCloud();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: CelestialTheme.bgCard,
                                            content: Text(ok ? 'Cloud accounts synchronized.' : 'Cloud sync failed. Check connection.'),
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                              icon: auth.isSyncingCloudAccounts
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                                    )
                                  : Icon(Icons.cloud_sync_rounded, color: CelestialTheme.goldLight, size: 18),
                              style: IconButton.styleFrom(
                                backgroundColor: CelestialTheme.bgCard,
                                padding: const EdgeInsets.all(8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: CelestialTheme.borderSubtle),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton.icon(
                              onPressed: () => _showAddAccountDialog(context, auth),
                              icon: const Icon(Icons.add_rounded, size: 15),
                              label: Text(
                                'Add Station',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11.5),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: CelestialTheme.goldPrimary,
                                foregroundColor: CelestialTheme.primaryBtnText,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search by terminal email or name...',
                              hintStyle: TextStyle(color: CelestialTheme.textMuted, fontSize: 13),
                              prefixIcon: Icon(Icons.search_rounded, size: 18, color: CelestialTheme.textMuted),
                              filled: true,
                              fillColor: CelestialTheme.bgCard,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: CelestialTheme.borderSubtle),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: CelestialTheme.borderSubtle),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: CelestialTheme.goldPrimary),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Tier Filter Segment
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: CelestialTheme.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: CelestialTheme.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              _buildFilterButton('All', 'all'),
                              _buildFilterButton('Trial', 'trial'),
                              _buildFilterButton('Pro', 'pro'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: auth.isSyncingCloudAccounts
                              ? null
                              : () async {
                                  final ok = await auth.syncManagedAccountsFromCloud();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: CelestialTheme.bgCard,
                                        content: Text(ok ? 'Cloud accounts synchronized.' : 'Cloud sync failed. Check connection.'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                          icon: auth.isSyncingCloudAccounts
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                                )
                              : Icon(Icons.cloud_sync_rounded, size: 16, color: CelestialTheme.goldLight),
                          label: Text(
                            auth.isSyncingCloudAccounts ? 'Syncing...' : 'Sync Cloud',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12, color: CelestialTheme.goldLight),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CelestialTheme.goldLight,
                            side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.35)),
                            backgroundColor: CelestialTheme.bgCard,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => _showAddAccountDialog(context, auth),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text(
                            'Add Station',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CelestialTheme.goldPrimary,
                            foregroundColor: CelestialTheme.primaryBtnText,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
            ),

            const Divider(height: 1, color: Colors.white12),

            // Managed Accounts List
            Expanded(
              child: accounts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.terminal_rounded, size: 48, color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text(
                            'No matching terminals or stations found',
                            style: GoogleFonts.outfit(color: CelestialTheme.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
                      itemCount: accounts.length,
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        return _buildAccountCard(context, auth, account, isMobile);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: CelestialTheme.textMuted,
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
  }

  Widget _buildFilterButton(String label, String value, {bool isExpanded = false}) {
    final isSelected = _tierFilter == value;
    final btn = InkWell(
      onTap: () => setState(() => _tierFilter = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isExpanded ? 4 : 10, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? CelestialTheme.goldPrimary.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? CelestialTheme.goldLight : CelestialTheme.textMuted,
            ),
          ),
        ),
      ),
    );
    if (isExpanded) {
      return Expanded(child: btn);
    }
    return btn;
  }

  Widget _buildAccountCard(BuildContext context, AuthService auth, AppUser account, bool isMobile) {
    final isPro = account.isPro;
    final isExpired = account.isTrialExpired;
    final isCustom = account.hasCustomTrial;
    final totalDays = isCustom ? account.customTrialDays : auth.defaultTrialDays;
    final remainingDays = account.trialDaysRemaining;
    final initial = account.email.isNotEmpty ? account.email[0].toUpperCase() : 'T';

    final deleteButton = IconButton(
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: CelestialTheme.bgSurface,
            title: const Text('Delete Terminal?', style: TextStyle(color: Colors.white)),
            content: Text(
              'Are you sure you want to remove ${account.email} from managed accounts?',
              style: TextStyle(color: CelestialTheme.textMuted),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: CelestialTheme.roseAlert),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Delete', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await auth.deleteManagedAccount(account.uid);
        }
      },
      icon: Icon(Icons.delete_outline_rounded, size: 18, color: CelestialTheme.textMuted),
      tooltip: 'Remove terminal',
      splashRadius: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPro
              ? CelestialTheme.goldPrimary.withValues(alpha: 0.4)
              : (isExpired ? CelestialTheme.roseAlert.withValues(alpha: 0.4) : CelestialTheme.borderSubtle),
          width: 1.0,
        ),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar + Station Name & Email + Delete button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isPro
                          ? CelestialTheme.goldPrimary
                          : (isExpired ? CelestialTheme.roseAlert.withValues(alpha: 0.2) : CelestialTheme.brownRich),
                      backgroundImage: (account.photoUrl != null && account.photoUrl!.isNotEmpty)
                          ? NetworkImage(account.photoUrl!)
                          : null,
                      child: (account.photoUrl != null && account.photoUrl!.isNotEmpty)
                          ? null
                          : Text(
                              initial,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isPro ? CelestialTheme.bgDark : CelestialTheme.textLight,
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  account.displayName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: CelestialTheme.textLight,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (account.isAdmin) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    'ADMIN',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: CelestialTheme.goldLight,
                                    ),
                                  ),
                                ),
                              ],
                              if (!account.isAdmin && account.disabledFeatures.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: CelestialTheme.roseAlert.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: CelestialTheme.roseAlert.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '${account.disabledFeatures.length} Restricted',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: CelestialTheme.roseAlert,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            account.email,
                            style: GoogleFonts.outfit(fontSize: 11.5, color: CelestialTheme.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    deleteButton,
                  ],
                ),

                const SizedBox(height: 10),

                // License / Trial Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isPro
                            ? CelestialTheme.emeraldReady
                            : (isExpired ? CelestialTheme.roseAlert : CelestialTheme.amberBrewing))
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isPro
                              ? CelestialTheme.emeraldReady
                              : (isExpired ? CelestialTheme.roseAlert : CelestialTheme.amberBrewing))
                          .withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPro ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                        size: 13,
                        color: isPro
                            ? CelestialTheme.emeraldReady
                            : (isExpired ? CelestialTheme.roseAlert : CelestialTheme.amberBrewing),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isPro
                              ? 'Active Pro Lifetime / Monthly License'
                              : (isExpired
                                  ? (totalDays == 0
                                      ? 'Trial Concluded (0 Days Remaining)'
                                      : 'Trial Expired (0 of $totalDays days remaining)')
                                  : '$remainingDays Days Remaining (of $totalDays ${isCustom ? "custom" : "default"} days)'),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isPro
                                ? CelestialTheme.emeraldReady
                                : (isExpired ? CelestialTheme.roseAlert : CelestialTheme.amberBrewing),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Action Buttons (Row 1: Tier & Trial controls)
                Row(
                  children: [
                    if (!isPro) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showCustomTrialDialog(context, auth, account),
                          icon: const Icon(Icons.edit_calendar_rounded, size: 14),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isCustom ? 'Custom ($totalDays d)' : 'Set Custom ($totalDays d)',
                              style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CelestialTheme.goldLight,
                            side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final newTier = isPro ? SubscriptionTier.trial : SubscriptionTier.pro;
                          await auth.updateAccountTier(account.uid, newTier);
                        },
                        icon: Icon(
                          isPro ? Icons.arrow_downward_rounded : Icons.star_rounded,
                          size: 14,
                        ),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isPro ? 'Set Trial' : 'Make Pro',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11.5),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPro ? CelestialTheme.brownRich : CelestialTheme.goldPrimary,
                          foregroundColor: isPro ? CelestialTheme.textLight : CelestialTheme.primaryBtnText,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Action Buttons (Row 2: Features & Reset PIN)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showAccountFeaturesDialog(context, auth, account),
                        icon: const Icon(Icons.tune_rounded, size: 14),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Features',
                            style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CelestialTheme.textLight,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          CreatePinDialog.show(
                            context,
                            email: account.email,
                            displayName: account.displayName,
                            isUpdate: true,
                          );
                        },
                        icon: const Icon(Icons.pin_outlined, size: 14),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Reset PIN',
                            style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CelestialTheme.goldLight,
                          side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Action Buttons (Row 3: View Sales History)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showClientSalesHistoryDialog(context, account),
                    icon: Icon(Icons.receipt_long_rounded, size: 14, color: CelestialTheme.goldLight),
                    label: Text(
                      'View Sales History',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.goldLight,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CelestialTheme.goldLight,
                      side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                // Station Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isPro
                      ? CelestialTheme.goldPrimary
                      : (isExpired ? CelestialTheme.roseAlert.withValues(alpha: 0.2) : CelestialTheme.brownRich),
                  backgroundImage: (account.photoUrl != null && account.photoUrl!.isNotEmpty)
                      ? NetworkImage(account.photoUrl!)
                      : null,
                  child: (account.photoUrl != null && account.photoUrl!.isNotEmpty)
                      ? null
                      : Text(
                          initial,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isPro ? CelestialTheme.bgDark : CelestialTheme.textLight,
                          ),
                        ),
                ),
                const SizedBox(width: 14),

                // Station Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              account.displayName,
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: CelestialTheme.textLight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (account.isAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: CelestialTheme.goldPrimary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'ADMIN',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.goldLight,
                                ),
                              ),
                            ),
                          ],
                          if (!account.isAdmin && account.disabledFeatures.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: CelestialTheme.roseAlert.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: CelestialTheme.roseAlert.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                '${account.disabledFeatures.length} Restricted',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.roseAlert,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        account.email,
                        style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isPro ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                            size: 13,
                            color: isPro
                                ? CelestialTheme.emeraldReady
                                : (isExpired ? CelestialTheme.roseAlert : CelestialTheme.amberBrewing),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              isPro
                                  ? 'Active Pro Lifetime / Monthly License'
                                  : (isExpired
                                      ? (totalDays == 0
                                          ? 'Trial Concluded (0 Days Remaining)'
                                          : 'Trial Expired (0 of $totalDays days remaining)')
                                      : '$remainingDays Days Remaining (of $totalDays ${isCustom ? "custom" : "default"} days)'),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isPro
                                    ? CelestialTheme.emeraldReady
                                    : (isExpired ? CelestialTheme.roseAlert : CelestialTheme.amberBrewing),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Action Buttons (Horizontally scrollable if viewport is tight)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Features Permissions Button
                      OutlinedButton.icon(
                        onPressed: () => _showAccountFeaturesDialog(context, auth, account),
                        icon: const Icon(Icons.tune_rounded, size: 15),
                        label: Text(
                          'Features',
                          style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CelestialTheme.textLight,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Reset Station PIN Button
                      OutlinedButton.icon(
                        onPressed: () {
                          CreatePinDialog.show(
                            context,
                            email: account.email,
                            displayName: account.displayName,
                            isUpdate: true,
                          );
                        },
                        icon: Icon(Icons.pin_outlined, size: 15, color: CelestialTheme.goldLight),
                        label: Text(
                          'Reset PIN',
                          style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CelestialTheme.goldLight,
                          side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // View Sales History Button
                      OutlinedButton.icon(
                        onPressed: () => _showClientSalesHistoryDialog(context, account),
                        icon: Icon(Icons.receipt_long_rounded, size: 15, color: CelestialTheme.goldLight),
                        label: Text(
                          'Sales',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.goldLight,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CelestialTheme.goldLight,
                          side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.35)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Custom Input Trial Action Button
                      if (!isPro) ...[
                        OutlinedButton.icon(
                          onPressed: () => _showCustomTrialDialog(context, auth, account),
                          icon: const Icon(Icons.edit_calendar_rounded, size: 15),
                          label: Text(
                            isCustom ? 'Custom Trial ($totalDays d)' : 'Set Custom ($totalDays d)',
                            style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CelestialTheme.goldLight,
                            side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Tier Switcher (Trial <-> Pro)
                      ElevatedButton.icon(
                        onPressed: () async {
                          final newTier = isPro ? SubscriptionTier.trial : SubscriptionTier.pro;
                          await auth.updateAccountTier(account.uid, newTier);
                        },
                        icon: Icon(
                          isPro ? Icons.arrow_downward_rounded : Icons.star_rounded,
                          size: 14,
                        ),
                        label: Text(
                          isPro ? 'Set Trial' : 'Make Pro',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPro ? CelestialTheme.brownRich : CelestialTheme.goldPrimary,
                          foregroundColor: isPro ? CelestialTheme.textLight : CelestialTheme.primaryBtnText,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),

                      const SizedBox(width: 6),

                      deleteButton,
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ClientSalesHistoryDialog extends StatefulWidget {
  final AppUser account;
  const _ClientSalesHistoryDialog({required this.account});

  @override
  State<_ClientSalesHistoryDialog> createState() => _ClientSalesHistoryDialogState();
}

class _ClientSalesHistoryDialogState extends State<_ClientSalesHistoryDialog> {
  late String _selectedYearMonth;
  late List<String> _availableMonths;
  bool _isLoading = true;
  List<Order> _orders = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYearMonth =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    _availableMonths = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
    });
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    final history = await CloudBackupService().fetchMonthlySalesHistory(
      userEmail: widget.account.email,
      yearMonth: _selectedYearMonth,
    );
    if (mounted) {
      setState(() {
        _orders = history;
        _isLoading = false;
      });
    }
  }

  double get _totalSales =>
      _orders.fold<double>(0.0, (sum, o) => sum + o.totalAmount);

  double get _averageTicket =>
      _orders.isEmpty ? 0.0 : (_totalSales / _orders.length);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 20,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 740,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        decoration: BoxDecoration(
          color: CelestialTheme.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: CelestialTheme.goldLight,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sales Transactions: ${widget.account.displayName}',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 16 : 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.account.email,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: CelestialTheme.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isLoading ? null : _loadSales,
                  icon: _isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(CelestialTheme.goldLight),
                          ),
                        )
                      : Icon(Icons.refresh_rounded, color: CelestialTheme.goldLight),
                  tooltip: 'Refresh Cloud Sales',
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  tooltip: 'Close',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Month Selector Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _availableMonths.map((ym) {
                  final isSelected = ym == _selectedYearMonth;
                  DateTime? parsed;
                  try {
                    final parts = ym.split('-');
                    parsed = DateTime(int.parse(parts[0]), int.parse(parts[1]));
                  } catch (_) {}
                  final label = parsed != null ? DateFormat('MMMM yyyy').format(parsed) : ym;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected && ym != _selectedYearMonth) {
                          setState(() => _selectedYearMonth = ym);
                          _loadSales();
                        }
                      },
                      labelStyle: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? CelestialTheme.primaryBtnText : CelestialTheme.textLight,
                      ),
                      selectedColor: CelestialTheme.goldPrimary,
                      backgroundColor: CelestialTheme.bgCard,
                      side: BorderSide(
                        color: isSelected
                            ? CelestialTheme.goldPrimary
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Metrics Summary Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Revenue',
                    value: '₱${_totalSales.toStringAsFixed(2)}',
                    icon: Icons.payments_outlined,
                    accentColor: CelestialTheme.goldPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Orders',
                    value: '${_orders.length}',
                    icon: Icons.receipt_long_outlined,
                    accentColor: Colors.blueAccent,
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Avg. Ticket',
                      value: '₱${_averageTicket.toStringAsFixed(2)}',
                      icon: Icons.analytics_outlined,
                      accentColor: Colors.purpleAccent,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Orders List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(CelestialTheme.goldPrimary),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Fetching cloud sales transactions...',
                            style: GoogleFonts.outfit(color: CelestialTheme.textMuted),
                          ),
                        ],
                      ),
                    )
                  : _orders.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cloud_off_rounded,
                                  size: 48,
                                  color: CelestialTheme.textMuted.withValues(alpha: 0.6),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No sales recorded in cloud for $_selectedYearMonth',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Orders taken while offline will automatically sync here as soon as the client device connects to the internet.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: CelestialTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _orders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final order = _orders[idx];
                            return _buildOrderTile(order);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(fontSize: 10.5, color: CelestialTheme.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTile(Order order) {
    final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(order.createdAt);
    final itemsSummary = order.items
        .map((i) => '${i.quantity}x ${i.menuItem.name}')
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      order.orderNumber,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: CelestialTheme.goldLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        order.orderType.name.toUpperCase(),
                        style: GoogleFonts.outfit(fontSize: 9.5, color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        order.paymentMethod.name.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.goldLight,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  itemsSummary.isEmpty ? 'Order details' : itemsSummary,
                  style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$dateStr • Cashier: ${order.cashierName}',
                  style: GoogleFonts.outfit(fontSize: 10.5, color: CelestialTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '₱${order.totalAmount.toStringAsFixed(2)}',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: CelestialTheme.goldPrimary,
            ),
          ),
        ],
      ),
    );
  }
}