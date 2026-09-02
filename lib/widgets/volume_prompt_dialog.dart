import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/celestial_theme.dart';

class VolumePromptDialog extends StatefulWidget {
  const VolumePromptDialog({super.key});

  /// Static helper to display the Volume Prompt modal without a close button.
  /// Automatically dismissed when the cashier presses the Volume Up or Volume Down button.
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => const VolumePromptDialog(),
    );
  }

  @override
  State<VolumePromptDialog> createState() => _VolumePromptDialogState();
}

class _VolumePromptDialogState extends State<VolumePromptDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _glowAlpha;
  final FocusNode _focusNode = FocusNode();

  bool _isDismissing = false;
  String? _detectedActionText;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAlpha = Tween<double>(begin: 0.25, end: 0.75).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Register hardware key listener for volume buttons
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);

    // Request autofocus on next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _focusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final logicalKey = event.logicalKey;
    final physicalKey = event.physicalKey;

    final isVolumeUp = logicalKey == LogicalKeyboardKey.audioVolumeUp ||
        physicalKey == PhysicalKeyboardKey.audioVolumeUp ||
        logicalKey == LogicalKeyboardKey.arrowUp ||
        logicalKey == LogicalKeyboardKey.numpadAdd ||
        logicalKey == LogicalKeyboardKey.equal;

    final isVolumeDown = logicalKey == LogicalKeyboardKey.audioVolumeDown ||
        physicalKey == PhysicalKeyboardKey.audioVolumeDown ||
        logicalKey == LogicalKeyboardKey.arrowDown ||
        logicalKey == LogicalKeyboardKey.numpadSubtract ||
        logicalKey == LogicalKeyboardKey.minus;

    final isVolumeOther = logicalKey == LogicalKeyboardKey.audioVolumeMute ||
        physicalKey == PhysicalKeyboardKey.audioVolumeMute ||
        logicalKey == LogicalKeyboardKey.keyV;

    if (isVolumeUp || isVolumeDown || isVolumeOther) {
      if (!_isDismissing) {
        _confirmAndClose(
          isVolumeUp
              ? 'Volume Up Detected (+)'
              : (isVolumeDown ? 'Volume Down Detected (-)' : 'Volume Button Detected'),
        );
      }
      return true;
    }

    return false;
  }

  void _confirmAndClose(String actionText) async {
    if (_isDismissing) return;
    setState(() {
      _isDismissing = true;
      _detectedActionText = actionText;
    });

    HapticFeedback.mediumImpact();

    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 600;

    return PopScope(
      canPop: false,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (_handleHardwareKey(event)) {
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 24,
            vertical: isMobile ? 16 : 24,
          ),
          child: Container(
            width: isMobile ? double.infinity : 460,
            constraints: BoxConstraints(
              maxHeight: mediaQuery.size.height * 0.92,
            ),
            decoration: BoxDecoration(
              color: CelestialTheme.bgSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isDismissing
                    ? CelestialTheme.emeraldReady
                    : CelestialTheme.goldPrimary.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.85),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: (_isDismissing
                          ? CelestialTheme.emeraldReady
                          : CelestialTheme.goldPrimary)
                      .withValues(alpha: 0.18),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Banner with Gradient
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: _isDismissing
                        ? const LinearGradient(
                            colors: [Color(0xFF0D3B36), Color(0xFF17131B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : CelestialTheme.brownGradient,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(22)),
                    border: Border(
                      bottom: BorderSide(
                        color: _isDismissing
                            ? CelestialTheme.emeraldReady.withValues(alpha: 0.4)
                            : CelestialTheme.goldPrimary.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: (_isDismissing
                                  ? CelestialTheme.emeraldReady
                                  : CelestialTheme.goldPrimary)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (_isDismissing
                                    ? CelestialTheme.emeraldReady
                                    : CelestialTheme.goldPrimary)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(
                          _isDismissing
                              ? Icons.check_circle_rounded
                              : Icons.volume_up_rounded,
                          color: _isDismissing
                              ? CelestialTheme.emeraldReady
                              : CelestialTheme.goldPrimary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AUDIO VOLUME NOTICE',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: _isDismissing
                                    ? CelestialTheme.emeraldReady
                                    : CelestialTheme.goldPrimary,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Cashier Alert System',
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: CelestialTheme.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Notice Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Text(
                          'HARDWARE KEY',
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: CelestialTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Body Content in SingleChildScrollView
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 22,
                      vertical: isMobile ? 16 : 20,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated Center Speaker Graphic
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _isDismissing ? 1.12 : _pulseScale.value,
                              child: Container(
                                width: 78,
                                height: 78,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isDismissing
                                      ? CelestialTheme.emeraldReady
                                          .withValues(alpha: 0.18)
                                      : CelestialTheme.goldPrimary
                                          .withValues(alpha: 0.14),
                                  border: Border.all(
                                    color: _isDismissing
                                        ? CelestialTheme.emeraldReady
                                        : CelestialTheme.goldPrimary.withValues(
                                            alpha: _glowAlpha.value),
                                    width: 2.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_isDismissing
                                              ? CelestialTheme.emeraldReady
                                              : CelestialTheme.goldPrimary)
                                          .withValues(
                                              alpha: _glowAlpha.value * 0.5),
                                      blurRadius: 24,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    _isDismissing
                                        ? Icons.check_rounded
                                        : Icons.volume_up_rounded,
                                    size: 38,
                                    color: _isDismissing
                                        ? CelestialTheme.emeraldReady
                                        : CelestialTheme.goldLight,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 14),

                        // Animated Equalizer Visualizer Bars
                        _buildEqualizer(),

                        const SizedBox(height: 14),

                        // Main Headline
                        Text(
                          _isDismissing
                              ? (_detectedActionText ?? 'Volume Acknowledged!')
                              : 'Please Turn Up Your Volume',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: isMobile ? 18 : 20,
                            fontWeight: FontWeight.bold,
                            color: _isDismissing
                                ? CelestialTheme.emeraldReady
                                : CelestialTheme.textLight,
                            letterSpacing: -0.3,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Subtitle / Notice Description
                        Text(
                          'Ensure POS station audio is turned UP so you hear incoming customer orders, kitchen ticket chimes, and order ready alarms.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                            color: CelestialTheme.textMuted,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Hardware Key Prompt Box (No Close Button on Modal)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: CelestialTheme.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _isDismissing
                                  ? CelestialTheme.emeraldReady
                                      .withValues(alpha: 0.5)
                                  : CelestialTheme.goldPrimary
                                      .withValues(alpha: 0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _buildHardwareKeyPill(
                                    icon: Icons.volume_up_rounded,
                                    label: 'VOL UP (+)',
                                    isHighlighted: !_isDismissing,
                                  ),
                                  Text(
                                    'or',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: CelestialTheme.textSubtle,
                                    ),
                                  ),
                                  _buildHardwareKeyPill(
                                    icon: Icons.volume_down_rounded,
                                    label: 'VOL DOWN (-)',
                                    isHighlighted: !_isDismissing,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.touch_app_outlined,
                                    size: 14,
                                    color: CelestialTheme.goldLight
                                        .withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      'Press physical volume button on device to dismiss',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: CelestialTheme.goldLight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEqualizer() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final val = _pulseController.value;
        final barHeights = [
          6.0 + (val * 12.0),
          12.0 + ((1.0 - val) * 14.0),
          18.0 + (val * 10.0),
          14.0 + ((1.0 - val) * 16.0),
          8.0 + (val * 10.0),
        ];

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(5, (index) {
            final color = _isDismissing
                ? CelestialTheme.emeraldReady
                : (index == 2
                    ? CelestialTheme.goldPrimary
                    : CelestialTheme.amberWarm);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4.5,
              height: barHeights[index],
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 5,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildHardwareKeyPill({
    required IconData icon,
    required String label,
    required bool isHighlighted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: CelestialTheme.bgSurfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted
              ? CelestialTheme.goldPrimary.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: 1.1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isHighlighted
                ? CelestialTheme.goldPrimary
                : CelestialTheme.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: isHighlighted
                  ? CelestialTheme.textLight
                  : CelestialTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
