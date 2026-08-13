import 'dart:ui';
import 'package:flutter/material.dart';

/// Fluent Design color system
class FluentColors {
  // Primary accent
  static const accentColor = Color(0xFF10B981); // Emerald green
  static const accentLight = Color(0xFF34D399);
  static const accentDark = Color(0xFF059669);
  static const accentSubtle = Color(0xFFD1FAE5);

  // Light theme
  static const cardBackground = Color(0xFFFFFFFF);
  static const subtleBackground = Color(0xFFF8FAFC);
  static const borderColor = Color(0xFFE2E8F0);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);

  // Dark theme
  static const cardBackgroundDark = Color(0xFF1E293B);
  static const subtleBackgroundDark = Color(0xFF0F172A);
  static const borderColorDark = Color(0xFF334155);
  static const textPrimaryDark = Color(0xFFF8FAFC);
  static const textSecondaryDark = Color(0xFF94A3B8);

  // Status colors
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);
}

/// Fluent Design tokens
class FluentDesignTokens {
  // Corner radius (Fluent uses softer corners)
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusExtraLarge = 20.0;

  // Spacing
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  // Elevation & shadows
  static const double elevationCard = 2.0;
  static const double elevationHover = 8.0;
  static const double elevationDialog = 16.0;

  // Animation durations (Fluent uses smooth transitions)
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // Acrylic blur
  static const double acrylicBlur = 30.0;
  static const double acrylicOpacity = 0.7;
}

/// Fluent-style acrylic card with blur effect
class FluentAcrylicCard extends StatefulWidget {
  const FluentAcrylicCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.elevation,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final VoidCallback? onTap;

  @override
  State<FluentAcrylicCard> createState() => _FluentAcrylicCardState();
}

class _FluentAcrylicCardState extends State<FluentAcrylicCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) {
        if (mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: FluentDesignTokens.animationNormal,
          curve: Curves.easeOutCubic,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FluentDesignTokens.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: _isHovered ? 20 : 10,
                offset: Offset(0, _isHovered ? 8 : 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(FluentDesignTokens.radiusLarge),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: FluentDesignTokens.acrylicBlur,
                sigmaY: FluentDesignTokens.acrylicBlur,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color:
                      (isDark
                              ? FluentColors.cardBackgroundDark
                              : FluentColors.cardBackground)
                          .withValues(alpha: FluentDesignTokens.acrylicOpacity),
                  border: Border.all(
                    color: isDark
                        ? FluentColors.borderColorDark.withValues(alpha: 0.5)
                        : FluentColors.borderColor.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(
                    FluentDesignTokens.radiusLarge,
                  ),
                ),
                padding:
                    widget.padding ??
                    const EdgeInsets.all(FluentDesignTokens.spacingMedium),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fluent-style button
class FluentButton extends StatefulWidget {
  const FluentButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.isPrimary = false,
    this.icon,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final IconData? icon;

  @override
  State<FluentButton> createState() => _FluentButtonState();
}

class _FluentButtonState extends State<FluentButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) {
        if (mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (mounted) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (mounted) setState(() => _isPressed = false);
        },
        onTapCancel: () {
          if (mounted) setState(() => _isPressed = false);
        },
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: FluentDesignTokens.animationFast,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: FluentDesignTokens.spacingLarge,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            gradient: widget.isPrimary
                ? LinearGradient(
                    colors: [FluentColors.accentColor, FluentColors.accentDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: !widget.isPrimary
                ? (isDark
                      ? FluentColors.cardBackgroundDark
                      : FluentColors.cardBackground)
                : null,
            borderRadius: BorderRadius.circular(
              FluentDesignTokens.radiusMedium,
            ),
            border: Border.all(
              color: widget.isPrimary
                  ? FluentColors.accentDark
                  : (isDark
                        ? FluentColors.borderColorDark
                        : FluentColors.borderColor),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isPrimary
                    ? FluentColors.accentColor.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: _isHovered ? 12 : 4,
                offset: Offset(0, _isHovered ? 6 : 2),
              ),
            ],
          ),
          transform: Matrix4.translationValues(
            0.0,
            _isPressed ? 2.0 : 0.0,
            0.0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  color: widget.isPrimary
                      ? Colors.white
                      : FluentColors.accentColor,
                  size: 20,
                ),
                const SizedBox(width: FluentDesignTokens.spacingSmall),
              ],
              DefaultTextStyle(
                style: TextStyle(
                  color: widget.isPrimary
                      ? Colors.white
                      : (isDark
                            ? FluentColors.textPrimaryDark
                            : FluentColors.textPrimary),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fluent-style text input
InputDecoration fluentInputDecoration({
  required BuildContext context,
  String? labelText,
  String? hintText,
  IconData? prefixIcon,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
    filled: true,
    fillColor: isDark
        ? FluentColors.subtleBackgroundDark
        : FluentColors.subtleBackground,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(FluentDesignTokens.radiusMedium),
      borderSide: BorderSide(
        color: isDark ? FluentColors.borderColorDark : FluentColors.borderColor,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(FluentDesignTokens.radiusMedium),
      borderSide: BorderSide(
        color: isDark ? FluentColors.borderColorDark : FluentColors.borderColor,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(FluentDesignTokens.radiusMedium),
      borderSide: const BorderSide(color: FluentColors.accentColor, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: FluentDesignTokens.spacingMedium,
      vertical: 14,
    ),
  );
}
