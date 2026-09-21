/// CollapsibleDataSection - Flutter collapsible section widget
import 'package:flutter/material.dart';
import '../models/banner.dart';
import '../services/banner_theme.dart';

class CollapsibleDataSection extends StatelessWidget {
  final String title;
  final List<dynamic> items;
  final bool isOpen;
  final VoidCallback onToggle;
  /// Translates dynamic (server-supplied) text via the banner's translation
  /// snapshot. Identity function if omitted.
  final String Function(String)? translate;
  /// "Common Appearance" theme (secondary/text colors, font) from the admin
  /// dashboard.
  final BannerTheme? theme;

  const CollapsibleDataSection({
    super.key,
    required this.title,
    required this.items,
    required this.isOpen,
    required this.onToggle,
    this.translate,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final mutedColor = theme?.textMuted ?? const Color(0xFF374151);
    final textColor = theme?.text ?? const Color(0xFF374151);
    final borderColor = theme?.border ?? Colors.grey[300]!;
    final fontFamily = theme?.fontFamily;

    return Column(
      children: [
        Divider(color: borderColor),
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$title (${items.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: mutedColor,
                    fontFamily: fontFamily,
                  ),
                ),
                Icon(
                  isOpen ? Icons.expand_less : Icons.expand_more,
                  color: mutedColor,
                ),
              ],
            ),
          ),
        ),
        if (isOpen)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map((item) {
                    final name = item is DataElement ||
                            item is ProcessingActivity ||
                            item is LegalEntity ||
                            item is Tool
                        ? item.name
                        : item.toString();
                    final localizedName = translate != null ? translate!(name) : name;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme?.background ?? Colors.white,
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        localizedName,
                        style: TextStyle(fontSize: 14, color: textColor, fontFamily: fontFamily),
                      ),
                    );
                  })
                  .toList(),
            ),
          ),
      ],
    );
  }
}

