import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';
import '../services/auth_service.dart';
import '../theme/celestial_theme.dart';
import '../widgets/privacy_agreement_dialog.dart';
import '../widgets/top_notification.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();

  bool _obscurePin = true;
  bool _userManuallyClearedEmail = false;
  bool _preferInputField = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRememberedEmail();
    });
  }

  Future<void> _loadRememberedEmail() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.init();
    await auth.checkActiveGoogleSession();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    _pinFocusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: CelestialTheme.bgCard,
        content: Text(msg, style: TextStyle(color: CelestialTheme.roseAlert)),
      ),
    );
  }

  void _showFeedback(String msg, {Color? color}) {
    if (!mounted) return;
    final feedbackColor = color ?? CelestialTheme.goldLight;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: CelestialTheme.bgCard,
        content: Text(msg, style: TextStyle(color: feedbackColor)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── SIGN IN with Email + PIN (or PIN-Only on Mobile) ────────────────────
  void _handlePinSignIn() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final email = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : (!_userManuallyClearedEmail ? (auth.lastStationEmail ?? '') : '');
    final pin = _pinController.text.trim();

    if (pin.isEmpty) {
      _showError('Please enter your 4-digit PIN.');
      return;
    }

    // 1. If station email is known or user entered it:
    if (email.isNotEmpty) {
      final cleanEmail = email.toLowerCase();
      final success = await auth.signInWithPin(email: cleanEmail, pin: pin);
      if (!mounted) return;
      if (success) return;

      final isAlreadyRegistered = auth.isEmailRegistered(cleanEmail) ||
          auth.hasPin(cleanEmail) ||
          await auth.checkRemoteHasPin(cleanEmail);
      if (!mounted) return;

      if (isAlreadyRegistered || auth.errorMessage == 'Incorrect PIN. Please try again.') {
        _showError(auth.errorMessage ?? 'Incorrect PIN. Please try again.');
        return;
      }

      if (auth.checkIfAdmin(cleanEmail)) {
        final regSuccess = await auth.setPinForUser(email: cleanEmail, pin: pin, autoSignIn: false);
        if (!mounted) return;
        if (!regSuccess && auth.errorMessage != null) {
          _showError(auth.errorMessage!);
        } else {
          _emailController.text = cleanEmail;
          _pinController.clear();
          _pinFocusNode.requestFocus();
          _showFeedback('Admin PIN configured! Please enter your 4-digit PIN below to continue.');
        }
      } else {
        _showRegisterConfirmDialog(cleanEmail, pin);
      }
      return;
    }

    // 2. PIN-Only Mode (Fast Mobile Login)
    final success = await auth.signInWithPinOnly(pin);
    if (!mounted) return;
    if (success) return;

    _showError(auth.errorMessage ?? 'Incorrect PIN. Please try again.');
  }

  void _showRegisterConfirmDialog(String email, String pin) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool agreedToTerms = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: CelestialTheme.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: CelestialTheme.goldPrimary, width: 1.2),
            ),
            actionsOverflowDirection: VerticalDirection.down,
            title: Row(
              children: [
                Icon(Icons.person_add_alt_1_rounded, color: CelestialTheme.goldPrimary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Register New Station?',
                    style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No existing account found for:',
                  style: GoogleFonts.outfit(color: CelestialTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: GoogleFonts.outfit(color: CelestialTheme.goldLight, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Text(
                  'Would you like to register a new POS station account with this 4-digit PIN?',
                  style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: CelestialTheme.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: agreedToTerms ? CelestialTheme.goldPrimary.withValues(alpha: 0.5) : CelestialTheme.borderWarm,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: agreedToTerms,
                          activeColor: CelestialTheme.goldPrimary,
                          checkColor: CelestialTheme.primaryBtnText,
                          onChanged: (val) {
                            setDialogState(() {
                              agreedToTerms = val ?? false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.outfit(fontSize: 12, color: CelestialTheme.textLight),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Terms of Service',
                                style: TextStyle(
                                  color: CelestialTheme.goldLight,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => PrivacyAgreementDialog.show(context, initialTab: 1),
                              ),
                              const TextSpan(text: ' & '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: CelestialTheme.goldLight,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => PrivacyAgreementDialog.show(context, initialTab: 0),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
              ),
              ElevatedButton(
                onPressed: !agreedToTerms
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        final auth = Provider.of<AuthService>(context, listen: false);
                        final isAlreadyRegistered = auth.isEmailRegistered(email) ||
                            auth.hasPin(email) ||
                            await auth.checkRemoteHasPin(email);
                        if (!mounted) return;
                        if (isAlreadyRegistered) {
                          _emailController.text = email;
                          _pinController.clear();
                          _pinFocusNode.requestFocus();
                          _showFeedback('Account already registered! Please enter your 4-digit PIN below to continue.');
                          return;
                        }

                        final success = await auth.setPinForUser(email: email, pin: pin, autoSignIn: false);
                        if (!mounted) return;
                        if (success) {
                          _emailController.text = email;
                          _pinController.clear();
                          _userManuallyClearedEmail = false;
                          await auth.rememberStationAccount(
                            email: email,
                            displayName: email.split('@').first,
                          );
                          setState(() {});
                          _pinFocusNode.requestFocus();
                          _showFeedback('Station PIN created! Please enter your 4-digit PIN below to continue.');
                        } else if (auth.errorMessage != null) {
                          _showError(auth.errorMessage!);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CelestialTheme.goldPrimary,
                  foregroundColor: CelestialTheme.primaryBtnText,
                  disabledBackgroundColor: CelestialTheme.goldPrimary.withValues(alpha: 0.3),
                  disabledForegroundColor: CelestialTheme.primaryBtnText.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Register & Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }



  // ── GOOGLE SIGN IN / SIGN UP ──────────────────────────────────────────────
  void _handleGoogleSignIn({bool isSignUp = false}) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final result = await auth.signInWithGoogle();
    if (!mounted) return;

    if (result == GoogleAuthResult.needsPin) {
      final email = auth.pendingGoogleUser?.email ?? '';
      final name = auth.pendingGoogleUser?.displayName;
      final photo = auth.pendingGoogleUser?.photoUrl;

      // Automatically fill email in the email box and save to recent login
      _emailController.text = email;
      _userManuallyClearedEmail = false;
      _pinController.clear();

      await auth.rememberStationAccount(
        email: email,
        displayName: name,
        photoUrl: photo,
        isGoogle: true,
      );

      final hasExistingPin = auth.hasPin(email) || auth.isEmailRegistered(email) || await auth.checkRemoteHasPin(email);
      if (!mounted) return;

      if (hasExistingPin) {
        // Return directly to login screen! User sees their Gmail filled out on input field
        // and inputs their 4-digit PIN to continue!
        _preferInputField = true;
        _userManuallyClearedEmail = false;
        _emailController.text = email;
        _pinController.clear();
        setState(() {});
        _pinFocusNode.requestFocus();
        _showFeedback(
          isSignUp
              ? 'Account already registered! Please enter your 4-digit PIN below to continue.'
              : 'Google account verified! Please enter your 4-digit PIN below to continue.',
        );
      } else {
        // First-time sign up with Google: prompt to create 4-digit PIN
        await _showGooglePinRegistrationDialog(email: email, displayName: name);
      }
    } else if (result == GoogleAuthResult.error) {
      _showError(auth.errorMessage ?? 'Google Sign-In was unable to complete. Please try again or use PIN.');
    }
  }

  // ── MODAL: CREATE PIN FOR NEW GOOGLE USER ─────────────────────────────────
  Future<void> _showGooglePinRegistrationDialog({required String email, String? displayName}) async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscurePin = true;
    bool obscureConfirm = true;
    String? localError;
    bool isSubmitting = false;
    bool agreedToTerms = false;
    final name = displayName ?? email.split('@').first;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final isMobile = MediaQuery.of(modalCtx).size.width < 600;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 20,
              vertical: isMobile ? 16 : 24,
            ),
            child: SingleChildScrollView(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: EdgeInsets.all(isMobile ? 20 : 28),
                decoration: BoxDecoration(
                  color: CelestialTheme.bgCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                        border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: Image.asset(
                            'assets/images/google_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.pin_rounded,
                              color: CelestialTheme.goldLight,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Register Station PIN',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.textLight,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Welcome, $name!\nCreate a 4-digit PIN for $email to complete your station setup.',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        color: CelestialTheme.textMuted,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (localError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: CelestialTheme.roseAlert.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: CelestialTheme.roseAlert.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: CelestialTheme.roseAlert, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                localError!,
                                style: GoogleFonts.outfit(color: CelestialTheme.roseAlert, fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Create 4-Digit PIN',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: CelestialTheme.textMuted),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: pinCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: obscurePin,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setModalState(() => localError = null),
                      style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontSize: 15, letterSpacing: obscurePin ? 6 : 2),
                      decoration: InputDecoration(
                        hintText: '4-digit PIN',
                        counterText: '',
                        filled: true,
                        fillColor: CelestialTheme.bgSurface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        prefixIcon: Icon(Icons.lock_outline_rounded, color: CelestialTheme.goldLight, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: CelestialTheme.textMuted, size: 18),
                          onPressed: () => setModalState(() => obscurePin = !obscurePin),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.goldPrimary)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Confirm 4-Digit PIN',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: CelestialTheme.textMuted),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: confirmCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: obscureConfirm,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setModalState(() => localError = null),
                      style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontSize: 15, letterSpacing: obscureConfirm ? 6 : 2),
                      decoration: InputDecoration(
                        hintText: 'Re-enter PIN',
                        counterText: '',
                        filled: true,
                        fillColor: CelestialTheme.bgSurface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        prefixIcon: Icon(Icons.lock_reset_rounded, color: CelestialTheme.goldLight, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: CelestialTheme.textMuted, size: 18),
                          onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.goldPrimary)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildPinDots(pinCtrl.text),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: agreedToTerms
                              ? CelestialTheme.goldPrimary.withValues(alpha: 0.5)
                              : CelestialTheme.borderWarm,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: agreedToTerms,
                              activeColor: CelestialTheme.goldPrimary,
                              checkColor: CelestialTheme.primaryBtnText,
                              onChanged: (val) {
                                setModalState(() {
                                  agreedToTerms = val ?? false;
                                  if (agreedToTerms) localError = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.outfit(fontSize: 12, color: CelestialTheme.textLight),
                                children: [
                                  const TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms of Service',
                                    style: TextStyle(
                                      color: CelestialTheme.goldLight,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => PrivacyAgreementDialog.show(context, initialTab: 1),
                                  ),
                                  const TextSpan(text: ' & '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                      color: CelestialTheme.goldLight,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => PrivacyAgreementDialog.show(context, initialTab: 0),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: (isSubmitting || !agreedToTerms)
                            ? null
                            : () async {
                                final pin = pinCtrl.text.trim();
                                final confirm = confirmCtrl.text.trim();
                                if (pin.length != 4 || int.tryParse(pin) == null) {
                                  setModalState(() => localError = 'PIN must be exactly 4 numeric digits.');
                                  return;
                                }
                                if (pin != confirm) {
                                  setModalState(() => localError = 'PINs do not match. Please verify.');
                                  return;
                                }
                                setModalState(() {
                                  isSubmitting = true;
                                  localError = null;
                                });
                                final auth = Provider.of<AuthService>(context, listen: false);
                                final isAlreadyRegistered = auth.hasPin(email) ||
                                    auth.isEmailRegistered(email) ||
                                    await auth.checkRemoteHasPin(email);
                                if (!ctx.mounted) return;
                                if (isAlreadyRegistered) {
                                  _preferInputField = true;
                                  _emailController.text = email;
                                  _pinController.clear();
                                  _userManuallyClearedEmail = false;
                                  await auth.rememberStationAccount(
                                    email: email,
                                    displayName: name,
                                    photoUrl: auth.pendingGoogleUser?.photoUrl,
                                    isGoogle: true,
                                  );
                                  if (ctx.mounted) {
                                    if (Navigator.of(ctx, rootNavigator: true).canPop()) {
                                      Navigator.of(ctx, rootNavigator: true).pop();
                                    } else if (TopNotification.navigatorKey.currentState?.canPop() ?? false) {
                                      TopNotification.navigatorKey.currentState?.pop();
                                    }
                                  }
                                  if (!mounted) return;
                                  setState(() {});
                                  _pinFocusNode.requestFocus();
                                  _showFeedback('Account already registered! Please enter your 4-digit PIN below to continue.');
                                  return;
                                }

                                final success = await auth.setPinForUser(
                                  email: email,
                                  pin: pin,
                                  autoSignIn: false,
                                );
                                if (success) {
                                  _preferInputField = false;
                                  _userManuallyClearedEmail = false;
                                  _emailController.clear();
                                  _pinController.clear();
                                  await auth.rememberStationAccount(
                                    email: email,
                                    displayName: name,
                                    photoUrl: auth.pendingGoogleUser?.photoUrl,
                                    isGoogle: true,
                                  );
                                  if (ctx.mounted) {
                                    if (Navigator.of(ctx, rootNavigator: true).canPop()) {
                                      Navigator.of(ctx, rootNavigator: true).pop();
                                    } else if (TopNotification.navigatorKey.currentState?.canPop() ?? false) {
                                      TopNotification.navigatorKey.currentState?.pop();
                                    }
                                  }
                                  if (!mounted) return;
                                  setState(() {});
                                  _pinFocusNode.requestFocus();
                                  _showFeedback('Station PIN created! Please enter your 4-digit PIN below to continue.');
                                  return;
                                }
                                if (!ctx.mounted) return;
                                setModalState(() {
                                  isSubmitting = false;
                                  localError = auth.errorMessage ?? 'Failed to register PIN.';
                                });
                              },
                        icon: isSubmitting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: CelestialTheme.primaryBtnText, strokeWidth: 2),
                              )
                            : Icon(Icons.check_circle_rounded, size: 18, color: CelestialTheme.primaryBtnText),
                        label: Text(
                          isSubmitting ? 'Registering...' : 'Register Station PIN',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.primaryBtnText,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CelestialTheme.goldPrimary,
                          foregroundColor: CelestialTheme.primaryBtnText,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        final auth = Provider.of<AuthService>(context, listen: false);
                        auth.cancelGoogleSignIn();
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.outfit(color: CelestialTheme.textMuted, fontSize: 12),
                      ),
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    if (!_userManuallyClearedEmail &&
        _emailController.text.trim().isEmpty &&
        auth.lastStationEmail != null &&
        auth.lastStationEmail!.isNotEmpty) {
      _emailController.text = auth.lastStationEmail!;
    }
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 700;

    return Scaffold(
      backgroundColor: CelestialTheme.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. High-resolution cinematic cafe background
          Positioned.fill(
            child: Image.asset(
              'assets/images/login_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          ),

          // 2. Cinematic Vignette and Dark Espresso Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.25,
                  colors: [
                    CelestialTheme.bgDark.withValues(alpha: 0.70),
                    CelestialTheme.bgDark.withValues(alpha: 0.88),
                    Colors.black.withValues(alpha: 0.96),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),



          // 4. Foreground Content with Frosted Glassmorphic Login Card
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 32, vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 460),
                    padding: EdgeInsets.all(isMobile ? 24 : 36),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141210).withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.65),
                          blurRadius: 40,
                          spreadRadius: 4,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Brand logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Builder(
                        builder: (ctx) {
                          final posProvider = Provider.of<PosProvider>(ctx);
                          if (posProvider.hasCustomLogo && posProvider.customLogoBytes != null) {
                            return Image.memory(
                              posProvider.customLogoBytes!,
                              fit: BoxFit.cover,
                            );
                          }
                          return Image.asset(
                            'assets/images/jc_pos_logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              'assets/images/Logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: CelestialTheme.bgSurface,
                                child: Icon(Icons.point_of_sale_rounded,
                                    color: CelestialTheme.goldPrimary, size: 36),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
                  Builder(
                    builder: (ctx) {
                      final pos = Provider.of<PosProvider>(ctx);
                      final displayName = (pos.storeName.isNotEmpty && pos.storeName != 'CELESTIAL CAFE')
                          ? pos.storeName
                          : 'JC POS SYSTEM';
                      return Text(
                        displayName,
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 20 : 22,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.textLight,
                          letterSpacing: 0.4,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  if (auth.isLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
                        decoration: BoxDecoration(
                          color: CelestialTheme.bgCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                color: CelestialTheme.goldPrimary,
                                strokeWidth: 2.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              auth.authStatusMessage ?? 'Connecting to Google...',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: CelestialTheme.textLight,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) && !(auth.authStatusMessage?.contains('browser') ?? false))
                                  ? 'Please complete sign-in on your device, or tap Cancel below.'
                                  : 'Please complete sign-in in the browser, or tap Cancel below.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                color: CelestialTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () {
                                auth.cancelGoogleSignIn();
                              },
                              icon: Icon(Icons.close_rounded, size: 16, color: CelestialTheme.amberBrewing),
                              label: Text(
                                'Cancel Sign-In',
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: CelestialTheme.amberBrewing,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: CelestialTheme.amberBrewing.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    _buildSignInForm(auth),
                  ],

                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => PrivacyAgreementDialog.show(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_user_outlined, size: 12, color: CelestialTheme.goldLight),
                              const SizedBox(width: 5),
                              Text(
                                'Privacy Policy & Terms of Agreement',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: CelestialTheme.goldLight,
                                  decoration: TextDecoration.underline,
                                  decorationColor: CelestialTheme.goldLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Developed by JC Celestial',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: CelestialTheme.textSubtle,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
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

  // ── SIGN IN FORM ──────────────────────────────────────────────────────────
  Widget _buildSignInForm(AuthService auth) {
    final cleanEmail = _emailController.text.trim().toLowerCase();
    final hasStationAccount = !_preferInputField &&
        !_userManuallyClearedEmail &&
        auth.lastStationEmail != null &&
        auth.lastStationEmail!.isNotEmpty;
    final stationEmail = (hasStationAccount ? (auth.lastStationEmail ?? '') : cleanEmail).trim().toLowerCase();
    final isRegistered = stationEmail.isNotEmpty && auth.isEmailRegistered(stationEmail);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasStationAccount) ...[
          _buildStationAccountCard(stationEmail, isRegistered, auth),
          const SizedBox(height: 14),
        ] else ...[
          // Email Input Field
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: _buildLabel(isRegistered ? 'Registered Gmail Address' : 'Gmail Address / Email'),
              ),
              if (isRegistered) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: CelestialTheme.emeraldReady.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '● Registered Account',
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: CelestialTheme.emeraldReady),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          _buildEmailField(),
          if (isRegistered) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: CelestialTheme.goldPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 13, color: CelestialTheme.goldLight),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Account registered. Please enter your 4-digit PIN below to access app.',
                      style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.goldLight, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
        ],
        // PIN Input Field
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: _buildLabel(isRegistered ? 'Registered 4-Digit PIN' : '4-Digit PIN'),
            ),
            if (isRegistered) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 11, color: CelestialTheme.goldLight),
                    const SizedBox(width: 4),
                    Text(
                      'Ready to Sign In',
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: CelestialTheme.goldLight),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        _buildPinField(
          controller: _pinController,
          focusNode: _pinFocusNode,
          obscure: _obscurePin,
          onToggle: () => setState(() => _obscurePin = !_obscurePin),
          hint: isRegistered ? 'Input your registered 4-digit PIN' : 'Enter your 4-digit PIN',
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _handlePinSignIn,
            icon: Icon(Icons.login_rounded, size: 18, color: CelestialTheme.primaryBtnText),
            label: Text(
              isRegistered ? 'Sign In to Station' : 'Sign In with PIN',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: CelestialTheme.primaryBtnText,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.goldPrimary,
              foregroundColor: CelestialTheme.primaryBtnText,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 18),
        // Divider: OR SIGN UP WITH GOOGLE
        Row(
          children: [
            Expanded(child: Divider(color: CelestialTheme.borderSubtle)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'OR SIGN UP WITH GOOGLE',
                style: GoogleFonts.outfit(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: CelestialTheme.textMuted,
                ),
              ),
            ),
            Expanded(child: Divider(color: CelestialTheme.borderSubtle)),
          ],
        ),
        const SizedBox(height: 16),
        // Dedicated Sign Up with Google Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _handleGoogleSignIn(isSignUp: true),
            icon: SizedBox(
              width: 20,
              height: 20,
              child: Image.asset(
                'assets/images/google_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.g_mobiledata_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
            ),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Sign Up with Google',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CelestialTheme.textLight,
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.bgSurface,
              foregroundColor: CelestialTheme.textLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: CelestialTheme.borderWarm),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted, height: 1.4),
              children: [
                const TextSpan(text: 'By signing up, you agree to our '),
                TextSpan(
                  text: 'Terms of Service',
                  style: TextStyle(
                    color: CelestialTheme.goldLight,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => PrivacyAgreementDialog.show(context, initialTab: 1),
                ),
                const TextSpan(text: ' & '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: TextStyle(
                    color: CelestialTheme.goldLight,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => PrivacyAgreementDialog.show(context, initialTab: 0),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStationAccountCard(String email, bool isRegistered, AuthService auth) {
    final rawDisplayName = auth.lastStationName ??
        (auth.currentUser?.email.toLowerCase() == email.toLowerCase() ? auth.currentUser?.displayName : null);
    final displayName = (rawDisplayName != null && rawDisplayName.trim().isNotEmpty)
        ? rawDisplayName.trim()
        : 'Station Gmail Account';
    final photoUrl = auth.lastStationPhoto ??
        (auth.currentUser?.email.toLowerCase() == email.toLowerCase() ? auth.currentUser?.photoUrl : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Recent Login'),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _pinController.clear();
              _pinFocusNode.requestFocus();
              _showFeedback('Please enter your 4-digit PIN below to continue.');
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: CelestialTheme.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isRegistered
                      ? CelestialTheme.goldPrimary.withValues(alpha: 0.35)
                      : CelestialTheme.borderWarm,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Circular User Avatar
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                      border: Border.all(
                        color: CelestialTheme.goldPrimary.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: (photoUrl != null && photoUrl.isNotEmpty)
                          ? Image.network(
                              photoUrl,
                              width: 42,
                              height: 42,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildStationAvatarFallback(displayName),
                            )
                          : _buildStationAvatarFallback(displayName),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name & Email
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          style: GoogleFonts.outfit(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: CelestialTheme.textLight,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: CelestialTheme.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Switch & Remove Action Buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _userManuallyClearedEmail = true;
                            _preferInputField = true;
                            _emailController.clear();
                            _pinController.clear();
                          });
                          auth.clearRememberedStationEmail();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.swap_horiz_rounded,
                                size: 13,
                                color: CelestialTheme.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Switch',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: CelestialTheme.textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _userManuallyClearedEmail = true;
                            _preferInputField = true;
                            _emailController.clear();
                            _pinController.clear();
                          });
                          auth.clearRememberedStationEmail();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Remove',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: CelestialTheme.textMuted,
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
        ),
      ],
    );
  }

  Widget _buildStationAvatarFallback(String name) {
    return Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: Image.asset(
          'assets/images/google_logo.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
            return Center(
              child: Text(
                initial,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: CelestialTheme.goldLight,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPinDots(String pin) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < pin.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: filled ? 12 : 10,
          height: filled ? 12 : 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? CelestialTheme.goldPrimary : Colors.transparent,
            border: Border.all(
              color: filled ? CelestialTheme.goldPrimary : CelestialTheme.borderWarm,
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }

  // ── SHARED INPUT WIDGETS ──────────────────────────────────────────────────

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: CelestialTheme.textMuted,
      ),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontSize: 13.5),
      onChanged: (val) {
        setState(() {});
      },
      decoration: InputDecoration(
        hintText: 'your.email@gmail.com',
        hintStyle: GoogleFonts.outfit(color: CelestialTheme.textSubtle, fontSize: 13),
        prefixIcon: Icon(Icons.email_outlined, color: CelestialTheme.goldLight, size: 18),
        filled: true,
        fillColor: CelestialTheme.bgSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: CelestialTheme.borderWarm),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: CelestialTheme.borderWarm, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: CelestialTheme.goldPrimary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required String hint,
    FocusNode? focusNode,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _handlePinSignIn(),
      maxLength: 4,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (val) {
        setState(() {});
      },
      style: GoogleFonts.outfit(
        color: CelestialTheme.textLight,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: obscure ? 6 : 2,
      ),
      textAlign: TextAlign.start,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(
          color: CelestialTheme.textSubtle,
          fontSize: 13,
          letterSpacing: 0,
          fontWeight: FontWeight.normal,
        ),
        counterText: '',
        filled: true,
        fillColor: CelestialTheme.bgSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixIcon: Icon(Icons.lock_outline_rounded, color: CelestialTheme.goldLight, size: 18),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: CelestialTheme.textMuted,
            size: 18,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: CelestialTheme.borderWarm),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: CelestialTheme.borderWarm, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: CelestialTheme.goldPrimary, width: 1.5),
        ),
      ),
    );
  }
}