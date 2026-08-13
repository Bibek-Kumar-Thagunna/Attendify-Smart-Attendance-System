import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/fluent_theme.dart';

/// Beautiful empty state widget with Fluent Design
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.color,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final emptyColor = color ?? FluentColors.textSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FluentDesignTokens.spacingXLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with gradient background
            Container(
              padding: const EdgeInsets.all(FluentDesignTokens.spacingLarge),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    emptyColor.withValues(alpha: 0.1),
                    emptyColor.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: emptyColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: FluentDesignTokens.spacingLarge),

            // Title
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),

            // Subtitle (optional)
            if (subtitle != null) ...[
              const SizedBox(height: FluentDesignTokens.spacingSmall),
              Text(
                subtitle!,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],

            // Action button (optional)
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: FluentDesignTokens.spacingLarge),
              FluentButton(
                onPressed: onAction,
                isPrimary: false,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state specifically for lists
class ListEmptyState extends StatelessWidget {
  const ListEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
  });

  final IconData icon;
  final String message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: icon,
      title: message,
      subtitle: hint,
      color: FluentColors.info,
    );
  }
}

/// Empty state for collections that don't exist yet
class CollectionEmptyState extends StatelessWidget {
  const CollectionEmptyState({
    super.key,
    required this.collectionName,
    this.hint,
  });

  final String collectionName;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.folder_off_outlined,
      title: 'No $collectionName Yet',
      subtitle: hint ?? 'Data will appear here once available',
      color: FluentColors.textSecondary,
    );
  }
}
