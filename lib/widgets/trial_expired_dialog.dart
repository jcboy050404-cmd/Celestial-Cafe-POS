import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../theme/celestial_theme.dart';
import 'top_notification.dart';

class TrialExpiredDialog extends StatefulWidget {
  const TrialExpiredDialog({super.key});

  static bool isShowing = false;

  static Future<void> show(BuildContext? context) async {
    if (isShowing) return;
    final targetContext = context ?? TopNotification.navigatorKey.currentContext;
    if (targetContext == null) return;

    isShowing = true;
    try {
      await showDialog<void>(
        context: targetContext,
        barrierDismissible: false,
        builder: (ctx) => const PopScope(
          canPop: false,
          child: TrialExpiredDialog(),
        ),
      );
    } finally {
      isShowing = false;
    }
  }

  @override
  State<TrialExpiredDialog> createState() => _TrialExpiredDialogState();
}

class _TrialExpiredDialogState extends State<TrialExpiredDialog> {
  bool _isCheckingLicense = false;
  static const String _devPrimaryEmail = 'jccelestial04@gmail.com';
  static const String _devName = 'JC Celestial';

  @override
  void dispose() {
    TrialExpiredDialog.isShowing = false;
    super.dispose();
  }

  Future<void> _contactDeveloperEmail(String userEmail) async {
    final subject = Uri.encodeComponent('Celestial POS Station License Activation - $userEmail');
    final body = Uri.encodeComponent(
      'Hello JC,\n\n'
      'Our POS terminal trial has ended and we would like to activate our station license.\n\n'
      'Station Email: $userEmail\n'
      'Terminal Platform: Flutter POS Workstation\n\n'
      'Please let us know the activation details.\n\n'
      'Thank you!',
    );
    final mailtoUri = Uri.parse('mailto:$_devPrimaryEmail?subject=$subject&body=$body');

    try {
      final launched = await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await _copyEmailToClipboard();
      }
    } catch (_) {
      if (mounted) {
        await _copyEmailToClipboard();
      }
    }
  }

  Future<void> _copyEmailToClipboard() async {
    await Clipboard.setData(const ClipboardData(text: _devPrimaryEmail));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: CelestialTheme.bgCard,
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: CelestialTheme.emeraldReady, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Developer email copied: $_devPrimaryEmail',
                style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRefreshLicense(AuthService auth) async {
    setState(() => _isCheckingLicense = true);
    final updated = await auth.refreshUserLicenseFromCloud();
    if (!mounted) return;
    setState(() => _isCheckingLicense = false);

    if (updated && (auth.isPro || (auth.currentUser?.trialDaysRemaining ?? 0) > 0 || auth.isAdmin)) {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      } else if (TopNotification.navigatorKey.currentState?.canPop() ?? false) {
        TopNotification.navigatorKey.currentState?.pop();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: CelestialTheme.bgSurface,
          content: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: CelestialTheme.goldPrimary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  auth.isPro
                      ? '✨ Pro License Active! Station unlocked.'
                      : '✨ Trial renewed! ${auth.currentUser?.trialDaysRemaining ?? 0} days available.',
                  style: TextStyle(color: CelestialTheme.goldLight, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: CelestialTheme.bgCard,
          content: Text(
            'Trial is still 0 days / expired. Please reach out to the developer to activate.',
            style: TextStyle(color: CelestialTheme.roseAlert),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final userEmail = user?.email ?? 'cashier@celestial.com';
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: EdgeInsets.all(isMobile ? 20 : 28),
          decoration: BoxDecoration(
            color: CelestialTheme.bgSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: CelestialTheme.roseAlert.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 36,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Glowing Icon Header
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CelestialTheme.roseAlert.withValues(alpha: 0.15),
                  border: Border.all(
                    color: CelestialTheme.roseAlert.withValues(alpha: 0.8),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CelestialTheme.roseAlert.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.timer_off_rounded,
                  color: CelestialTheme.roseAlert,
                  size: 32,
                ),
              ),

              const SizedBox(height: 16),

              // Title
              Text(
                'Free Trial Has Concluded',
                style: GoogleFonts.outfit(
                  fontSize: isMobile ? 19 : 22,
                  fontWeight: FontWeight.bold,
                  color: CelestialTheme.textLight,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 6),

              // Station Email Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: CelestialTheme.roseAlert.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: CelestialTheme.roseAlert.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_clock_rounded, size: 12, color: CelestialTheme.roseAlert),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '0 Days Remaining • $userEmail',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.roseAlert,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Body Message
              Text(
                'The trial period for this POS station has reached 0 days. All cafe menu items, inventory, categories, and sales receipts remain safely preserved on cloud servers.',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  color: CelestialTheme.textMuted,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 18),

              // Developer Contact Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CelestialTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.support_agent_rounded, color: CelestialTheme.goldLight, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Contact Developer for License Activation',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.goldLight,
                                ),
                              ),
                              Text(
                                'Developer: $_devName',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: CelestialTheme.textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _copyEmailToClipboard(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: CelestialTheme.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: CelestialTheme.borderWarm),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.email_outlined, color: CelestialTheme.goldPrimary, size: 15),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _devPrimaryEmail,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: CelestialTheme.textLight,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.copy_rounded, color: CelestialTheme.textMuted, size: 14),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: ElevatedButton.icon(
                        onPressed: () => _contactDeveloperEmail(userEmail),
                        icon: const Icon(Icons.send_rounded, size: 14),
                        label: Text(
                          'Email Developer to Unlock',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CelestialTheme.goldPrimary,
                          foregroundColor: CelestialTheme.primaryBtnText,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Action Buttons
              Row(
                children: [
                  // Refresh License Check Button
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _isCheckingLicense ? null : () => _handleRefreshLicense(auth),
                        icon: _isCheckingLicense
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(color: CelestialTheme.goldLight, strokeWidth: 2),
                              )
                            : Icon(Icons.sync_rounded, size: 16, color: CelestialTheme.goldLight),
                        label: Text(
                          _isCheckingLicense ? 'Checking...' : 'Refresh License',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.goldLight,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Sign Out Station Button
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (Navigator.of(context, rootNavigator: true).canPop()) {
                            Navigator.of(context, rootNavigator: true).pop();
                          }
                          await auth.signOut();
                        },
                        icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.white),
                        label: Text(
                          'Sign Out',
                          style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CelestialTheme.roseAlert,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}