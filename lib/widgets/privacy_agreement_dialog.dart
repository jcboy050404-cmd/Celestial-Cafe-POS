import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/celestial_theme.dart';

/// Modal dialog displaying the Privacy Policy and Terms of Agreement for JC POS SYSTEM / Celestial Cafe POS.
class PrivacyAgreementDialog extends StatefulWidget {
  final bool requireExplicitAcceptance;
  final int initialTab;

  const PrivacyAgreementDialog({
    super.key,
    this.requireExplicitAcceptance = false,
    this.initialTab = 0,
  });

  /// Shows the Privacy and Terms dialog. Returns `true` if user tapped "I Agree / Accept".
  static Future<bool?> show(
    BuildContext context, {
    bool requireExplicitAcceptance = false,
    int initialTab = 0,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: !requireExplicitAcceptance,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => PrivacyAgreementDialog(
        requireExplicitAcceptance: requireExplicitAcceptance,
        initialTab: initialTab,
      ),
    );
  }

  @override
  State<PrivacyAgreementDialog> createState() => _PrivacyAgreementDialogState();
}

class _PrivacyAgreementDialogState extends State<PrivacyAgreementDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 24,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        decoration: BoxDecoration(
          color: CelestialTheme.bgSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: CelestialTheme.goldPrimary.withValues(alpha: 0.45),
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
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              decoration: BoxDecoration(
                color: CelestialTheme.bgCard,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(
                          Icons.verified_user_outlined,
                          color: CelestialTheme.goldLight,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Privacy & User Agreement',
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: CelestialTheme.textLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'JC POS System · Store Owner & Station Terms',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: CelestialTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context, false),
                        icon: Icon(
                          Icons.close_rounded,
                          color: CelestialTheme.textMuted,
                          size: 20,
                        ),
                        splashRadius: 18,
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Tab Bar
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        gradient: CelestialTheme.goldGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: CelestialTheme.primaryBtnText,
                      unselectedLabelColor: CelestialTheme.textMuted,
                      labelStyle: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedLabelStyle: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: const [
                        Tab(text: 'Privacy Policy'),
                        Tab(text: 'Terms of Agreement'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable Tab Content ────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPrivacyPolicyContent(),
                  _buildTermsContent(),
                ],
              ),
            ),

            // ── Footer Action Buttons ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: CelestialTheme.bgCard,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(21)),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_clock_outlined,
                    size: 14,
                    color: CelestialTheme.goldLight,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Last updated: September 2026 · JC Celestial',
                      style: TextStyle(
                        fontSize: 11,
                        color: CelestialTheme.textMuted,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Close',
                      style: GoogleFonts.outfit(
                        color: CelestialTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CelestialTheme.goldPrimary,
                      foregroundColor: CelestialTheme.primaryBtnText,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'I Understand & Agree',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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

  Widget _buildPrivacyPolicyContent() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('1. Data Collection & Multi-Store Isolation', Icons.domain_verification_rounded),
        _buildParagraph(
          'JC POS System enforces strict multi-tenant data isolation. Each store owner\'s menu items, categories, recipes, pricing, stock levels, and order history are kept separate under their own private storage namespace. Store owners cannot access or inspect data belonging to another business.',
        ),
        const SizedBox(height: 14),

        _buildSectionHeader('2. Authentication & 4-Digit PIN Security', Icons.lock_outline_rounded),
        _buildParagraph(
          'To ensure high station security and prevent unauthorized access, all station credentials and PIN codes are encrypted using cryptographic SHA-256 one-way hashing with salt before local persistence or remote verification. Raw plaintext PINs are never stored on your device or in our databases.',
        ),
        const SizedBox(height: 14),

        _buildSectionHeader('3. Cashier Staff & Station Privacy', Icons.badge_outlined),
        _buildParagraph(
          'Cashier accounts created by store owners are restricted strictly to point-of-sale operations (order taking, customer checkout, and receipt printing). Cashier accounts are prevented from inspecting sensitive business financial costing, food margins, or altering pricing and store settings.',
        ),
        const SizedBox(height: 14),

        _buildSectionHeader('4. Local Offline Storage & Cloud Synchronization', Icons.cloud_sync_outlined),
        _buildParagraph(
          'All transaction entries and sales receipts are recorded immediately on your device using local offline-first storage to guarantee continuous operations even when network connectivity is disrupted. When connected to the internet, data synchronizes securely with authorized cloud servers to safeguard against device loss.',
        ),
        const SizedBox(height: 14),

        _buildSectionHeader('5. Third-Party Services & Google Sign-In', Icons.g_mobiledata_rounded),
        _buildParagraph(
          'When signing in or registering using Google Sign-In, we only request your basic email and public profile name for station identity verification. We never access your contacts, private emails, Google Drive files, or payment instruments.',
        ),
      ],
    );
  }

  Widget _buildTermsContent() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('1. License & Permitted Usage', Icons.assignment_turned_in_outlined),
        _buildParagraph(
          'JC POS System provides a point-of-sale and store management software license for cafe, restaurant, and retail establishments. You agree to use the software solely for legitimate business order processing, inventory tracking, and sales analytics.',
        ),
        const SizedBox(height: 14),

        _buildSectionHeader('2. Store Owner Responsibilities', Icons.admin_panel_settings_outlined),
        _buildParagraph(
          'Store Owners (Pro Accounts) are responsible for managing station PINs, authorizing staff cashier accounts, and reviewing sales transaction totals. Store Owners must maintain the confidentiality of administrative credentials to prevent unauthorized inventory or pricing adjustments.',
        ),
        const SizedBox(height: 14),

        _buildSectionHeader('3. Cashier Station Limitations', Icons.point_of_sale_rounded),
        _buildParagraph(
          'Cashier accounts operate in POS-Only mode. Cashier staff cannot modify menu prices, override product stock, alter store settings, or clear historical sales registers. Attempting to circumvent role restrictions violates our acceptable use agreement.',
        ),
        const SizedBox(height: 14),

        _buildSectionHeader('4. Sales Records & Tax Compliance', Icons.receipt_long_rounded),
        _buildParagraph(
          'Sales history and receipt numbers are tracked sequentially to provide transparent audit trails. Store owners remain responsible for local business tax reporting, tax exemptions (e.g. Senior Citizen/PWD discounts), and financial record retention required under local government laws.',
        ),
        const SizedBox(height: 14),

        _buildSectionHeader('5. Disclaimer & System Availability', Icons.security_rounded),
        _buildParagraph(
          'While JC POS System is built with offline persistence and resilient cloud synchronization, users are advised to maintain periodic cloud backup syncs. The developer (JC Celestial) provides system updates and software maintenance under applicable support terms.',
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: CelestialTheme.goldLight),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: CelestialTheme.textLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 5),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: CelestialTheme.textMuted,
          height: 1.45,
        ),
      ),
    );
  }
}
