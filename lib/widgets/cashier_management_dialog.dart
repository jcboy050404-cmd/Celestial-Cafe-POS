import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_feature.dart';
import '../services/auth_service.dart';
import '../theme/celestial_theme.dart';
import 'top_notification.dart';

/// Modal dialog for Store Owners to manage their store's cashier stations.
/// Multi-tenant: Each owner only sees and manages their own cashiers.
class CashierManagementDialog extends StatefulWidget {
  const CashierManagementDialog({super.key});

  static Future<void> show(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (!auth.isOwnerOrAdmin) {
      TopNotification.show(
        context,
        message: 'Access Denied: Store Owner privileges required.',
        icon: Icons.lock_outline_rounded,
        backgroundColor: CelestialTheme.roseAlert,
      );
      return Future.value();
    }
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => const CashierManagementDialog(),
    );
  }

  @override
  State<CashierManagementDialog> createState() => _CashierManagementDialogState();
}

class _CashierManagementDialogState extends State<CashierManagementDialog> {
  void _showAddCashierDialog(BuildContext context, AuthService auth) {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();

    bool obscurePin = true;
    bool obscureConfirm = true;
    String? errorMessage;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: CelestialTheme.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5), width: 1.2),
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.person_add_alt_1_rounded, color: CelestialTheme.goldLight, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Add Cashier Station',
                              style: GoogleFonts.outfit(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: CelestialTheme.textLight,
                              ),
                            ),
                          ],
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

                    // Access callout
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CelestialTheme.goldPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined, color: CelestialTheme.goldLight, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cashiers only have access to POS sales and receipts. They strictly cannot edit products, change prices, or modify store settings.',
                              style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textLight, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Cashier Email
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Cashier Email / Username',
                        hintText: 'e.g. cashier1@mycafe.com',
                        labelStyle: TextStyle(color: CelestialTheme.textMuted, fontSize: 12.5),
                        hintStyle: TextStyle(color: CelestialTheme.textSubtle, fontSize: 11.5),
                        prefixIcon: Icon(Icons.email_outlined, color: CelestialTheme.goldPrimary, size: 18),
                        filled: true,
                        fillColor: CelestialTheme.bgCard,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 10),

                    // Cashier Display Name
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Cashier Station Name',
                        hintText: 'e.g. Main Counter Cashier',
                        labelStyle: TextStyle(color: CelestialTheme.textMuted, fontSize: 12.5),
                        hintStyle: TextStyle(color: CelestialTheme.textSubtle, fontSize: 11.5),
                        prefixIcon: Icon(Icons.badge_outlined, color: CelestialTheme.goldPrimary, size: 18),
                        filled: true,
                        fillColor: CelestialTheme.bgCard,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 10),

                    // 4-Digit PIN Row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pinController,
                            keyboardType: TextInputType.number,
                            obscureText: obscurePin,
                            maxLength: 4,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              labelText: '4-Digit PIN',
                              counterText: '',
                              labelStyle: TextStyle(color: CelestialTheme.textMuted, fontSize: 12),
                              prefixIcon: Icon(Icons.pin_outlined, color: CelestialTheme.goldPrimary, size: 18),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 16,
                                  color: CelestialTheme.textMuted,
                                ),
                                onPressed: () => setModalState(() => obscurePin = !obscurePin),
                              ),
                              filled: true,
                              fillColor: CelestialTheme.bgCard,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            style: const TextStyle(color: Colors.white, fontSize: 13, letterSpacing: 2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: confirmPinController,
                            keyboardType: TextInputType.number,
                            obscureText: obscureConfirm,
                            maxLength: 4,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              labelText: 'Confirm PIN',
                              counterText: '',
                              labelStyle: TextStyle(color: CelestialTheme.textMuted, fontSize: 12),
                              prefixIcon: Icon(Icons.lock_outline_rounded, color: CelestialTheme.goldPrimary, size: 18),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 16,
                                  color: CelestialTheme.textMuted,
                                ),
                                onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                              ),
                              filled: true,
                              fillColor: CelestialTheme.bgCard,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            style: const TextStyle(color: Colors.white, fontSize: 13, letterSpacing: 2),
                          ),
                        ),
                      ],
                    ),

                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: GoogleFonts.outfit(color: CelestialTheme.roseAlert, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel', style: GoogleFonts.outfit(color: CelestialTheme.textMuted)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final email = emailController.text.trim();
                                  final name = nameController.text.trim();
                                  final pin = pinController.text.trim();
                                  final confirm = confirmPinController.text.trim();

                                  if (email.isEmpty || !email.contains('@')) {
                                    setModalState(() => errorMessage = 'Please enter a valid email address.');
                                    return;
                                  }
                                  if (pin.length != 4 || int.tryParse(pin) == null) {
                                    setModalState(() => errorMessage = 'PIN must be exactly 4 numeric digits.');
                                    return;
                                  }
                                  if (pin != confirm) {
                                    setModalState(() => errorMessage = 'PINs do not match.');
                                    return;
                                  }

                                  setModalState(() {
                                    isSaving = true;
                                    errorMessage = null;
                                  });

                                  final success = await auth.createCashierAccount(
                                    email: email,
                                    displayName: name.isEmpty ? email.split('@').first : name,
                                    pin: pin,
                                  );

                                  if (success) {
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      TopNotification.showSuccess(
                                        context,
                                        'Cashier account created for $email with PIN $pin',
                                      );
                                    }
                                  } else {
                                    setModalState(() {
                                      isSaving = false;
                                      errorMessage = auth.errorMessage ?? 'Failed to create cashier.';
                                    });
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Icon(Icons.check_rounded, size: 16),
                          label: Text(isSaving ? 'Creating...' : 'Create Cashier', style: const TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CelestialTheme.goldPrimary,
                            foregroundColor: CelestialTheme.primaryBtnText,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  void _showResetPinDialog(BuildContext context, AuthService auth, AppUser cashier) {
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();
    String? errorMessage;
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: CelestialTheme.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
            ),
            title: Row(
              children: [
                Icon(Icons.pin_outlined, color: CelestialTheme.goldLight, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Update PIN: ${cashier.displayName}',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter a new 4-digit PIN for ${cashier.email}:',
                  style: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: obscure,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'New 4-Digit PIN',
                    counterText: '',
                    prefixIcon: Icon(Icons.lock_reset_rounded, color: CelestialTheme.goldPrimary, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16),
                      onPressed: () => setModalState(() => obscure = !obscure),
                    ),
                    filled: true,
                    fillColor: CelestialTheme.bgCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 13, letterSpacing: 2),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmPinController,
                  keyboardType: TextInputType.number,
                  obscureText: obscure,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Confirm New PIN',
                    counterText: '',
                    prefixIcon: Icon(Icons.check_circle_outline_rounded, color: CelestialTheme.goldPrimary, size: 18),
                    filled: true,
                    fillColor: CelestialTheme.bgCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 13, letterSpacing: 2),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: TextStyle(color: CelestialTheme.roseAlert, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final pin = pinController.text.trim();
                  final confirm = confirmPinController.text.trim();
                  if (pin.length != 4 || int.tryParse(pin) == null) {
                    setModalState(() => errorMessage = 'PIN must be exactly 4 digits.');
                    return;
                  }
                  if (pin != confirm) {
                    setModalState(() => errorMessage = 'PINs do not match.');
                    return;
                  }

                  final success = await auth.updateCashierPin(email: cashier.email, newPin: pin);
                  if (success) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      TopNotification.showSuccess(context, 'PIN updated for ${cashier.email}');
                    }
                  } else {
                    setModalState(() => errorMessage = 'Failed to update PIN.');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CelestialTheme.goldPrimary,
                  foregroundColor: CelestialTheme.primaryBtnText,
                ),
                child: const Text('Save PIN'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPermissionsDialog(BuildContext context, AuthService auth, AppUser cashier) {
    List<String> selectedDisabled = List.from(cashier.disabledFeatures);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: CelestialTheme.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Permissions: ${cashier.displayName}',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                            ),
                            Text(
                              cashier.email,
                              style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded, color: CelestialTheme.textMuted, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Configure what this cashier station can access. Locked features cannot be modified or seen by the cashier.',
                      style: TextStyle(fontSize: 11.5, color: CelestialTheme.textMuted),
                    ),
                    const SizedBox(height: 12),

                    // Quick Preset
                    Row(
                      children: [
                        Text('Presets: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CelestialTheme.textMuted)),
                        ActionChip(
                          label: const Text('Cashier Only (Recommended)', style: TextStyle(fontSize: 10.5)),
                          backgroundColor: CelestialTheme.bgCard,
                          side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                          labelStyle: TextStyle(color: CelestialTheme.goldLight, fontWeight: FontWeight.bold),
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
                      ],
                    ),
                    const SizedBox(height: 12),

                    ...AppFeature.allFeatures.map((feat) {
                      final isEnabled = !selectedDisabled.contains(feat.key);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isEnabled ? CelestialTheme.bgCard : Colors.red.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isEnabled ? Colors.white.withValues(alpha: 0.06) : CelestialTheme.roseAlert.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(feat.icon, size: 16, color: isEnabled ? CelestialTheme.goldLight : CelestialTheme.roseAlert),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(feat.title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isEnabled ? Colors.white : CelestialTheme.textMuted)),
                                  Text(feat.description, style: TextStyle(fontSize: 9.5, color: CelestialTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            Switch(
                              value: isEnabled,
                              activeTrackColor: CelestialTheme.goldPrimary,
                              onChanged: (val) {
                                setDialogState(() {
                                  if (val) {
                                    selectedDisabled.remove(feat.key);
                                  } else {
                                    if (!selectedDisabled.contains(feat.key)) {
                                      selectedDisabled.add(feat.key);
                                    }
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            await auth.updateAccountDisabledFeatures(cashier.uid, selectedDisabled);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              TopNotification.showSuccess(context, 'Permissions updated for ${cashier.email}');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CelestialTheme.goldPrimary,
                            foregroundColor: CelestialTheme.primaryBtnText,
                          ),
                          child: const Text('Save Permissions'),
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

  void _confirmDeleteCashier(BuildContext context, AuthService auth, AppUser cashier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        title: Text('Remove Cashier Station?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to remove ${cashier.displayName} (${cashier.email})? This station will no longer be able to sign in.',
          style: TextStyle(color: CelestialTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await auth.deleteCashierAccount(cashier.uid);
              if (success && context.mounted) {
                TopNotification.showSuccess(context, 'Cashier station removed.');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: CelestialTheme.roseAlert),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final cashiers = auth.getCashiersForCurrentOwner();
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 20,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        padding: EdgeInsets.all(isMobile ? 16 : 22),
        decoration: BoxDecoration(
          color: CelestialTheme.bgSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.75),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.people_alt_rounded, color: CelestialTheme.goldLight, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cashier & Staff Stations',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.textLight,
                          ),
                        ),
                        Text(
                          'Store: ${auth.currentUser?.email ?? "Active Store"}',
                          style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.goldLight),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: CelestialTheme.textMuted, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Explanatory note
            Text(
              'Create custom login credentials (Email & 4-digit PIN) for your cashiers. Cashiers only have POS access and cannot modify products, pricing, stock, or store settings.',
              style: GoogleFonts.outfit(fontSize: 11.5, color: CelestialTheme.textMuted, height: 1.3),
            ),
            const SizedBox(height: 14),

            // Top CTA Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ACTIVE CASHIER STATIONS (${cashiers.length})',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: CelestialTheme.goldLight,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddCashierDialog(context, auth),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Cashier Station', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CelestialTheme.goldPrimary,
                    foregroundColor: CelestialTheme.primaryBtnText,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // List of cashiers
            Expanded(
              child: cashiers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.point_of_sale_outlined, size: 48, color: CelestialTheme.textMuted.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'No Cashier Stations Yet',
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap "+ Add Cashier Station" above to create a custom email and 4-digit PIN for your counter cashiers.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(fontSize: 12, color: CelestialTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: cashiers.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final cashier = cashiers[index];
                        final initial = cashier.displayName.isNotEmpty ? cashier.displayName[0].toUpperCase() : 'C';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: CelestialTheme.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: CelestialTheme.brownRich,
                                child: Text(
                                  initial,
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: CelestialTheme.goldLight),
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
                                          cashier.displayName,
                                          style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.lock_rounded, size: 8, color: CelestialTheme.goldLight),
                                              const SizedBox(width: 3),
                                              Text(
                                                'CASHIER • CANNOT MODIFY',
                                                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      cashier.email,
                                      style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Reset PIN Button
                              IconButton(
                                onPressed: () => _showResetPinDialog(context, auth, cashier),
                                icon: Icon(Icons.pin_outlined, size: 18, color: CelestialTheme.goldLight),
                                tooltip: 'Change Station PIN',
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                              ),
                              // Permissions Button
                              IconButton(
                                onPressed: () => _showPermissionsDialog(context, auth, cashier),
                                icon: Icon(Icons.tune_rounded, size: 18, color: CelestialTheme.textLight),
                                tooltip: 'Permissions',
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                              ),
                              // Delete Button
                              IconButton(
                                onPressed: () => _confirmDeleteCashier(context, auth, cashier),
                                icon: Icon(Icons.delete_outline_rounded, size: 18, color: CelestialTheme.roseAlert),
                                tooltip: 'Remove Cashier',
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
