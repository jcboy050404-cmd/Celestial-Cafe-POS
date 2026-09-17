import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/celestial_theme.dart';

/// Type of top notification for automated styling
enum TopNotificationType {
  success,
  warning,
  error,
  info,
}

/// Global top notification manager that floats sleek alerts down from the top of the screen.
///
/// Designed to replace bottom snackbars for order completions, handovers, warnings,
/// and cart actions, ensuring high visibility over workstation controls and dialogs.
class TopNotification {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static OverlayEntry? _currentEntry;
  static _TopNotificationWidgetState? _currentState;

  /// Display a custom top notification overlay
  static void show(
    BuildContext? context, {
    required String message,
    String? title,
    IconData? icon,
    Color? iconColor,
    Color? backgroundColor,
    Color? borderColor,
    Color? textColor,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 2500),
    bool showCloseIcon = true,
    TopNotificationType type = TopNotificationType.info,
    Widget? customContent,
  }) {
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    } catch (_) {}

    // Resolve overlay
    OverlayState? overlayState;
    if (context != null && context.mounted) {
      overlayState = Overlay.maybeOf(context, rootOverlay: true);
    }
    overlayState ??= navigatorKey.currentState?.overlay;

    if (overlayState == null) return;

    // Dismiss existing notification
    dismissCurrent(immediate: true);

    // Resolve default colors and icons based on type
    final resolvedIcon = icon ?? _defaultIconForType(type);
    final resolvedIconColor = iconColor ?? _defaultIconColorForType(type);
    final resolvedBg = backgroundColor ?? const Color(0xFF1E293B);
    final resolvedBorder = borderColor ?? const Color(0xFF334155);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TopNotificationWidget(
        message: message,
        title: title,
        icon: resolvedIcon,
        iconColor: resolvedIconColor,
        backgroundColor: resolvedBg,
        borderColor: resolvedBorder,
        textColor: textColor ?? Colors.white,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        showCloseIcon: showCloseIcon,
        customContent: customContent,
        onDismissed: () {
          if (_currentEntry == entry) {
            _currentEntry = null;
          }
          entry.remove();
        },
        onReady: (state) {
          _currentState = state;
        },
      ),
    );

    _currentEntry = entry;
    overlayState.insert(entry);
  }

  /// Specialized method for order completion & handover with UNDO button
  static void showOrderHandedOver(
    BuildContext? context, {
    required dynamic orderNumber,
    VoidCallback? onUndo,
    String? message,
  }) {
    HapticFeedback.heavyImpact();
    show(
      context,
      message: message ?? 'Order $orderNumber completed & handed over!',
      type: TopNotificationType.success,
      icon: Icons.check_circle_rounded,
      iconColor: const Color(0xFF22C55E),
      actionLabel: onUndo != null ? 'UNDO' : null,
      onAction: onUndo,
      duration: const Duration(milliseconds: 2600),
    );
  }

  /// Quick success notification
  static void showSuccess(
    BuildContext? context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    HapticFeedback.mediumImpact();
    show(
      context,
      message: message,
      type: TopNotificationType.success,
      icon: Icons.check_circle_rounded,
      iconColor: const Color(0xFF22C55E),
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Quick warning notification
  static void showWarning(
    BuildContext? context,
    String message, {
    Duration duration = const Duration(milliseconds: 2600),
  }) {
    HapticFeedback.mediumImpact();
    show(
      context,
      message: message,
      type: TopNotificationType.warning,
      icon: Icons.warning_amber_rounded,
      iconColor: const Color(0xFFFF9F1C),
      duration: duration,
    );
  }

  /// Quick error or void notification
  static void showError(
    BuildContext? context,
    String message, {
    Duration duration = const Duration(milliseconds: 2600),
  }) {
    HapticFeedback.heavyImpact();
    show(
      context,
      message: message,
      type: TopNotificationType.error,
      icon: Icons.error_outline_rounded,
      iconColor: CelestialTheme.roseAlert,
      duration: duration,
    );
  }

  /// Quick informational notification
  static void showInfo(
    BuildContext? context,
    String message, {
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    HapticFeedback.lightImpact();
    show(
      context,
      message: message,
      type: TopNotificationType.info,
      icon: Icons.info_outline_rounded,
      iconColor: const Color(0xFF38BDF8),
      duration: duration,
    );
  }

  /// Adapt an existing Flutter SnackBar into a sleek top notification
  static void showSnackBar(BuildContext context, SnackBar snackBar) {
    String? message;
    Widget? customContent;

    if (snackBar.content is Text) {
      message = (snackBar.content as Text).data;
    } else {
      customContent = snackBar.content;
    }

    show(
      context,
      message: message ?? '',
      customContent: customContent,
      backgroundColor: snackBar.backgroundColor ?? const Color(0xFF1E293B),
      duration: snackBar.duration,
      actionLabel: snackBar.action?.label,
      onAction: snackBar.action?.onPressed,
      showCloseIcon: snackBar.showCloseIcon ?? true,
    );
  }

  /// Dismiss the currently visible top notification
  static void dismissCurrent({bool immediate = false}) {
    if (immediate) {
      final entry = _currentEntry;
      _currentEntry = null;
      _currentState = null;
      entry?.remove();
    } else {
      _currentState?.dismiss();
    }
  }

  static IconData _defaultIconForType(TopNotificationType type) {
    switch (type) {
      case TopNotificationType.success:
        return Icons.check_circle_rounded;
      case TopNotificationType.warning:
        return Icons.warning_amber_rounded;
      case TopNotificationType.error:
        return Icons.error_outline_rounded;
      case TopNotificationType.info:
        return Icons.info_outline_rounded;
    }
  }

  static Color _defaultIconColorForType(TopNotificationType type) {
    switch (type) {
      case TopNotificationType.success:
        return const Color(0xFF22C55E);
      case TopNotificationType.warning:
        return const Color(0xFFFF9F1C);
      case TopNotificationType.error:
        return CelestialTheme.roseAlert;
      case TopNotificationType.info:
        return CelestialTheme.goldPrimary;
    }
  }
}

class _TopNotificationWidget extends StatefulWidget {
  final String message;
  final String? title;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showCloseIcon;
  final Duration duration;
  final Widget? customContent;
  final VoidCallback onDismissed;
  final void Function(_TopNotificationWidgetState) onReady;

  const _TopNotificationWidget({
    required this.message,
    this.title,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    this.actionLabel,
    this.onAction,
    required this.duration,
    required this.showCloseIcon,
    this.customContent,
    required this.onDismissed,
    required this.onReady,
  });

  @override
  State<_TopNotificationWidget> createState() => _TopNotificationWidgetState();
}

class _TopNotificationWidgetState extends State<_TopNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _timer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    widget.onReady(this);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _controller.forward();

    _timer = Timer(widget.duration, () {
      if (mounted) {
        dismiss();
      }
    });
  }

  void dismiss() {
    _timer?.cancel();
    _timer = null;
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final screenWidth = mediaQuery.size.width;
    final maxAllowedWidth = screenWidth > 520 ? 440.0 : screenWidth - 28.0;

    return Positioned(
      top: topPadding + 12,
      left: (screenWidth - maxAllowedWidth) / 2,
      width: maxAllowedWidth,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta != null && details.primaryDelta! < -4) {
                  dismiss();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: widget.borderColor, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Status Icon with soft glow container
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.iconColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.icon, color: widget.iconColor, size: 20),
                    ),
                    const SizedBox(width: 10),

                    // Main Content
                    Expanded(
                      child: widget.customContent ??
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.title != null) ...[
                                Text(
                                  widget.title!,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: widget.iconColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                              Text(
                                widget.message,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: widget.textColor,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                    ),

                    // Action button (e.g. UNDO)
                    if (widget.actionLabel != null && widget.onAction != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          dismiss();
                          widget.onAction!();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        child: Text(
                          widget.actionLabel!,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: CelestialTheme.goldPrimary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],

                    // Close (✕) button
                    if (widget.showCloseIcon) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: dismiss,
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
