import 'dart:io';
import 'package:flutter/material.dart';
import '../models/menu_item.dart';
import '../theme/celestial_theme.dart';

/// High-performance unified thumbnail/media widget for menu items.
///
/// Automatically uses cached [MenuItem.imageBytes] to avoid repeated
/// [base64Decode] operations on every frame, seamlessly supports assets,
/// files, and falls back gracefully to category emoji icons.
class ItemThumbnail extends StatelessWidget {
  final MenuItem item;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final double? iconSize;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final Color? backgroundColor;

  const ItemThumbnail({
    super.key,
    required this.item,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.iconSize,
    this.border,
    this.boxShadow,
    this.backgroundColor,
  });

  Widget _buildFallback(BuildContext context, double resolvedIconSize) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: item.inStock
            ? CelestialTheme.brownGradient
            : const LinearGradient(
                colors: [Color(0xFF2C2C2C), Color(0xFF1A1A1A)],
              ),
        borderRadius: borderRadius ?? BorderRadius.circular(10),
        border: border,
        boxShadow: boxShadow,
      ),
      child: Center(
        child: Text(
          item.icon,
          style: TextStyle(
            fontSize: resolvedIconSize,
            color: item.inStock ? null : Colors.grey,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedIconSize = iconSize ??
        ((width != null && width! < 60)
            ? 20.0
            : (width != null && width! < 100)
                ? 30.0
                : 40.0);

    final resolvedRadius = borderRadius ?? BorderRadius.circular(10);
    final bytes = item.imageBytes;
    final path = item.imagePath;

    Widget? mediaChild;

    if (bytes != null && bytes.isNotEmpty) {
      mediaChild = Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => _buildFallback(context, resolvedIconSize),
      );
    } else if (path != null && path.isNotEmpty) {
      if (path.startsWith('assets/')) {
        mediaChild = Image.asset(
          path,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) => _buildFallback(context, resolvedIconSize),
        );
      } else {
        mediaChild = Image.file(
          File(path),
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) => _buildFallback(context, resolvedIconSize),
        );
      }
    }

    if (mediaChild == null) {
      return _buildFallback(context, resolvedIconSize);
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFF140E18),
        borderRadius: resolvedRadius,
        border: border,
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: resolvedRadius,
        child: mediaChild,
      ),
    );
  }
}
