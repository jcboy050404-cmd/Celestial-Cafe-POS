import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/celestial_theme.dart';
import 'admin_management_dialog.dart';

class UpgradeProDialog extends StatelessWidget {
  const UpgradeProDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => const UpgradeProDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final isPro = auth.isPro;
    final isAdmin = auth.isAdmin;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: CelestialTheme.bgSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 24,
              offset: const Offset(0, 8),
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
                        color: CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                      ),
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: CelestialTheme.goldPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'POS Subscription',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.textLight,
                          ),
                        ),
                        Text(
                          user?.email ?? 'Account Details',
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
                  icon: Icon(Icons.close_rounded, color: CelestialTheme.textMuted),
                  splashRadius: 18,
                ),
              ],
            ),

            const SizedBox(height: 18),
            Divider(color: CelestialTheme.borderSubtle, height: 1),
            const SizedBox(height: 18),

            // Current Status Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CelestialTheme.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isPro ? CelestialTheme.goldPrimary.withValues(alpha: 0.5) : CelestialTheme.borderWarm,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isPro ? CelestialTheme.goldPrimary : CelestialTheme.amberBrewing,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPro
                          ? (isAdmin ? 'ADMIN PRO' : 'PRO LICENSE')
                          : '${auth.defaultTrialDays}D FREE TRIAL',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.primaryBtnText,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPro
                              ? (isAdmin ? 'Pro Active (Administrator Account)' : 'Pro Active (Licensed by Admin)')
                              : '${user?.hasCustomTrial == true ? user!.customTrialDays : auth.defaultTrialDays}-Day Free Trial',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: CelestialTheme.textLight,
                          ),
                        ),
                        Text(
                          isPro
                              ? 'All premium POS capabilities unlocked'
                              : '${user?.trialDaysRemaining ?? auth.defaultTrialDays} days remaining on trial',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: CelestialTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Feature Checklist
            Text(
              'PRO CAPABILITIES',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: CelestialTheme.goldLight,
              ),
            ),
            const SizedBox(height: 10),

            _buildFeatureRow(
              'Unlimited Daily Transactions',
              'Process unlimited orders without daily throughput restrictions',
            ),
            _buildFeatureRow(
              'Custom Receipt Branding & Thermal Printing',
              'Upload cafe logo and remove trial watermark from printed receipts',
            ),
            _buildFeatureRow(
              'Advanced Analytics & PDF Export',
              'Detailed hourly sales curve, payment method distribution & daily report',
            ),
            _buildFeatureRow(
              'Unlimited Catalog & Custom Categories',
              'Create unlimited custom categories, modifiers, and beverage variants',
            ),
            _buildFeatureRow(
              'Cloud Email Backup & Restore',
              'Automatic cloud recovery for your cafe settings, logo, and license even after reinstalling or clearing app data',
            ),

            const SizedBox(height: 16),

            // Admin vs Non-Admin Notice & Actions
            if (!isAdmin) ...[
              // Policy Notice for Regular Users
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CelestialTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.admin_panel_settings_rounded, color: CelestialTheme.goldLight, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin-Managed Station License',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.goldLight,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isPro
                                ? 'This station has been granted a Pro license by the store administrator.'
                                : 'Only authorized store administrators can activate Pro licenses or grant trial extensions. Please contact your manager or store owner to upgrade this terminal.',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: CelestialTheme.textMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Non-Admin Actions: Only Close
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CelestialTheme.bgCard,
                      foregroundColor: CelestialTheme.textLight,
                      side: BorderSide(color: CelestialTheme.borderWarm),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text('Close', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ] else ...[
              // Admin View: Information and Portal Shortcuts
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: CelestialTheme.goldLight, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Administrator License Controls',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.goldLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'You are logged in as an administrator. You can configure station licenses, set custom trial periods, and toggle Pro access for all terminals in the Admin Portal.',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: CelestialTheme.textLight,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Admin Actions: Open Admin Portal
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      AdminManagementDialog.show(context);
                    },
                    icon: const Icon(Icons.admin_panel_settings_rounded, size: 16),
                    label: Text(
                      'Open Admin Portal',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CelestialTheme.goldPrimary,
                      foregroundColor: CelestialTheme.primaryBtnText,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

  Widget _buildFeatureRow(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline_rounded, color: CelestialTheme.goldPrimary, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CelestialTheme.textLight,
                  ),
                ),
                Text(
                  desc,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: CelestialTheme.textSubtle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}