import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GlassDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  final String hint;
  final Widget? icon;

  const GlassDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          hint: Row(
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 12)],
              Text(hint, style: GoogleFonts.outfit(color: Colors.white54)),
            ],
          ),
          dropdownColor: const Color(0xFF1E293B),
          style: GoogleFonts.outfit(color: Colors.white),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
          isExpanded: true,
        ),
      ),
    );
  }
}
