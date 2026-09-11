import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/celestial_theme.dart';
import 'top_notification.dart';

class CreatePinDialog extends StatefulWidget {
  final String email;
  final String? displayName;
  final bool isUpdate;

  const CreatePinDialog({
    super.key,
    required this.email,
    this.displayName,
    this.isUpdate = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String email,
    String? displayName,
    bool isUpdate = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: isUpdate,
      builder: (ctx) => CreatePinDialog(
        email: email,
        displayName: displayName,
        isUpdate: isUpdate,
      ),
    );
  }

  @override
  State<CreatePinDialog> createState() => _CreatePinDialogState();
}

class _CreatePinDialogState extends State<CreatePinDialog> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _handleSavePin() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() {
        _errorMessage = 'PIN must be exactly 4 numeric digits.';
      });
      return;
    }

    if (pin != confirm) {
      setState(() {
        _errorMessage = 'PINs do not match. Please verify and try again.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final success = await auth.setPinForUser(
      email: widget.email,
      pin: pin,
    );

    if (success) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else if (TopNotification.navigatorKey.currentState?.canPop() ?? false) {
        TopNotification.navigatorKey.currentState?.pop(true);
      }
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _errorMessage = auth.errorMessage ?? 'Failed to save PIN. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.displayName ?? widget.email.split('@').first;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
            // Glowing Icon Header
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
              child: const Icon(
                Icons.pin_rounded,
                color: CelestialTheme.goldLight,
                size: 30,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              widget.isUpdate ? 'Update Station PIN' : 'Create Station PIN',
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
              widget.isUpdate
                  ? 'Update your 4-digit terminal PIN for ${widget.email}.'
                  : 'Welcome, $name! Set a 4-digit PIN for ${widget.email} to enable fast terminal sign-in.',
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                color: CelestialTheme.textMuted,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 22),

            // Error banner
            if (_errorMessage != null) ...[
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
                        _errorMessage!,
                        style: GoogleFonts.outfit(color: CelestialTheme.roseAlert, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Input: 4-digit PIN
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Enter 4-Digit PIN',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: CelestialTheme.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 6),
            _buildPinInput(
              controller: _pinController,
              obscure: _obscurePin,
              onToggle: () => setState(() => _obscurePin = !_obscurePin),
              hint: '4-digit PIN',
            ),

            const SizedBox(height: 14),

            // Input: Confirm PIN
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Confirm 4-Digit PIN',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: CelestialTheme.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 6),
            _buildPinInput(
              controller: _confirmPinController,
              obscure: _obscureConfirmPin,
              onToggle: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin),
              hint: 'Re-enter PIN',
            ),

            const SizedBox(height: 16),

            // PIN Dots preview
            _buildPinDots(_pinController.text),

            const SizedBox(height: 24),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSavePin,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: CelestialTheme.bgDark,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : (widget.isUpdate ? 'Update PIN' : 'Save Station PIN'),
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

            if (!widget.isUpdate) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: Text(
                  'Set Up Later',
                  style: GoogleFonts.outfit(
                    color: CelestialTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildPinInput({
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: TextInputType.number,
      maxLength: 4,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {
        _errorMessage = null;
      }),
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
}
