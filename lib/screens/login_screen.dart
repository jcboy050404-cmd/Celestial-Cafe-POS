import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/celestial_theme.dart';
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
        content: Text(msg, style: const TextStyle(color: CelestialTheme.roseAlert)),
      ),
    );
  }

  void _showFeedback(String msg, {Color color = CelestialTheme.goldLight}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: CelestialTheme.bgCard,
        content: Text(msg, style: TextStyle(color: color)),
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
      builder: (ctx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: CelestialTheme.goldPrimary, width: 1.2),
        ),
        actionsOverflowDirection: VerticalDirection.down,
        title: Row(
          children: [
            const Icon(Icons.person_add_alt_1_rounded, color: CelestialTheme.goldPrimary, size: 22),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
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
              foregroundColor: CelestialTheme.bgDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Register & Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
                        border: Border.all(color: CelestialTheme.goldPrimary, width: 1.8),
                        boxShadow: [
                          BoxShadow(
                            color: CelestialTheme.goldPrimary.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
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
                            errorBuilder: (context, error, stackTrace) => const Icon(
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
                            const Icon(Icons.error_outline_rounded, color: CelestialTheme.roseAlert, size: 16),
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
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: CelestialTheme.goldLight, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: CelestialTheme.textMuted, size: 18),
                          onPressed: () => setModalState(() => obscurePin = !obscurePin),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CelestialTheme.borderWarm)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CelestialTheme.borderWarm)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CelestialTheme.goldPrimary)),
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
                        prefixIcon: const Icon(Icons.lock_reset_rounded, color: CelestialTheme.goldLight, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: CelestialTheme.textMuted, size: 18),
                          onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CelestialTheme.borderWarm)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CelestialTheme.borderWarm)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CelestialTheme.goldPrimary)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildPinDots(pinCtrl.text),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting
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
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: CelestialTheme.bgDark, strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text(
                          isSubmitting ? 'Registering...' : 'Register Station PIN',
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CelestialTheme.goldPrimary,
                          foregroundColor: CelestialTheme.bgDark,
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
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 32, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            padding: EdgeInsets.all(isMobile ? 24 : 36),
            decoration: BoxDecoration(
              color: CelestialTheme.bgCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: CelestialTheme.borderWarm, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
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
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: CelestialTheme.goldPrimary.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/Logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: CelestialTheme.bgSurface,
                          child: const Icon(Icons.local_cafe_rounded,
                              color: CelestialTheme.goldPrimary, size: 32),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
                  Text(
                    'JC POS System',
                    style: GoogleFonts.outfit(
                      fontSize: isMobile ? 20 : 22,
                      fontWeight: FontWeight.bold,
                      color: CelestialTheme.textLight,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Professional POS Terminal System',
                    style: GoogleFonts.outfit(fontSize: 12, color: CelestialTheme.textMuted),
                    textAlign: TextAlign.center,
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
                            const SizedBox(
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
                              icon: const Icon(Icons.close_rounded, size: 16, color: CelestialTheme.amberBrewing),
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

                  const SizedBox(height: 16),
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
                  const Icon(Icons.lock_outline_rounded, size: 13, color: CelestialTheme.goldLight),
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
                    const Icon(Icons.check_circle_outline_rounded, size: 11, color: CelestialTheme.goldLight),
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
            icon: const Icon(Icons.login_rounded, size: 18),
            label: Text(
              isRegistered ? 'Sign In to Station' : 'Sign In with PIN',
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.goldPrimary,
              foregroundColor: CelestialTheme.bgDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 18),
        // Divider: OR SIGN UP WITH GOOGLE
        Row(
          children: [
            const Expanded(child: Divider(color: CelestialTheme.borderSubtle)),
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
            const Expanded(child: Divider(color: CelestialTheme.borderSubtle)),
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
                side: const BorderSide(color: CelestialTheme.borderWarm),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStationAccountCard(String email, bool isRegistered, AuthService auth) {
    final displayName = auth.lastStationName ?? (auth.currentUser?.email.toLowerCase() == email.toLowerCase() ? auth.currentUser?.displayName : null);
    final photoUrl = auth.lastStationPhoto ?? (auth.currentUser?.email.toLowerCase() == email.toLowerCase() ? auth.currentUser?.photoUrl : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _pinController.clear();
          _pinFocusNode.requestFocus();
          _showFeedback('Please enter your 4-digit PIN below to continue.');
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: CelestialTheme.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRegistered
                  ? CelestialTheme.goldPrimary.withValues(alpha: 0.5)
                  : CelestialTheme.borderWarm,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Recent Login pill + Station Gmail Account + Remove / Switch
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history_rounded, size: 12, color: CelestialTheme.goldLight),
                        const SizedBox(width: 4),
                        Text(
                          'Recent Login',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.goldLight,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Station Gmail Account',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: CelestialTheme.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _userManuallyClearedEmail = true;
                        _preferInputField = true;
                        _emailController.clear();
                        _pinController.clear();
                      });
                      auth.clearRememberedStationEmail();
                    },
                    icon: const Icon(Icons.close_rounded, size: 12, color: CelestialTheme.roseAlert),
                    label: Text(
                      'Remove',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: CelestialTheme.roseAlert,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 2),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _userManuallyClearedEmail = true;
                        _preferInputField = true;
                        _emailController.clear();
                        _pinController.clear();
                      });
                      auth.clearRememberedStationEmail();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Switch',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: CelestialTheme.amberBrewing,
                      ),
                    ),
                  ),
                ],
              ),
          const SizedBox(height: 10),
          // User Identity Row: Avatar / Photo + Name + Email + Status
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                  border: Border.all(
                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: (photoUrl != null && photoUrl.isNotEmpty)
                      ? Image.network(
                          photoUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: Image.asset(
                                'assets/images/google_logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.account_circle_rounded,
                                  color: CelestialTheme.goldLight,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: Image.asset(
                              'assets/images/google_logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.account_circle_rounded,
                                color: CelestialTheme.goldLight,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (displayName != null && displayName.isNotEmpty) ...[
                      Text(
                        displayName,
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.textLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                    ],
                    Text(
                      email,
                      style: GoogleFonts.outfit(
                        fontSize: displayName != null ? 12 : 13.5,
                        fontWeight: displayName != null ? FontWeight.w500 : FontWeight.bold,
                        color: CelestialTheme.goldLight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isRegistered) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: CelestialTheme.emeraldReady.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: CelestialTheme.emeraldReady.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 10, color: CelestialTheme.emeraldReady),
                      const SizedBox(width: 4),
                      Text(
                        'Ready',
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.emeraldReady,
                        ),
                      ),
                    ],
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
        prefixIcon: const Icon(Icons.email_outlined, color: CelestialTheme.goldLight, size: 18),
        filled: true,
        fillColor: CelestialTheme.bgSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CelestialTheme.borderWarm),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CelestialTheme.borderWarm, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CelestialTheme.goldPrimary, width: 1.5),
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
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: CelestialTheme.goldLight, size: 18),
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
          borderSide: const BorderSide(color: CelestialTheme.borderWarm),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CelestialTheme.borderWarm, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CelestialTheme.goldPrimary, width: 1.5),
        ),
      ),
    );
  }
}
