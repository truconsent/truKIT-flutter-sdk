/// ModernBannerFooter - Flutter banner footer widget
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/banner_theme.dart';

class ModernBannerFooter extends StatelessWidget {
  final String footerText;
  final String orgName;
  final BannerTheme? theme;
  /// Translates dynamic (server-supplied) text via the banner's translation
  /// snapshot. Identity function if omitted.
  final String Function(String)? translate;

  const ModernBannerFooter({
    super.key,
    required this.footerText,
    required this.orgName,
    this.theme,
    this.translate,
  });

  String _processPlaceholder(String text) {
    return text.replaceAll('[Organization Name]', orgName);
  }

  List<TextSpan> _parseMarkdownLinks(String text, Color linkColor, String? fontFamily) {
    final regex = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }

      final linkText = match.group(1)!;
      var url = match.group(2)!.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }

      spans.add(
        TextSpan(
          text: linkText,
          style: TextStyle(
            color: linkColor,
            fontFamily: fontFamily,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
        ),
      );

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return spans.isEmpty ? [TextSpan(text: text)] : spans;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedTheme = theme ?? const BannerTheme(
      background: Color(0xFFFFFFFF),
      text: Color(0xFF111827),
      textMuted: Color(0xFF6B7280),
      button: Color(0xFF9333EA),
      buttonText: Color(0xFFFFFFFF),
      border: Color(0xFFE5E7EB),
      fontSize: 16,
    );
    final translateFn = translate ?? (String t) => t;
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final fontSize = isMobile ? 11.0 : 12.0;

    final processedText = _processPlaceholder(translateFn(footerText));
    // Matches truKIT-NPM's ModernBannerFooter.jsx exactly: link color is
    // var(--banner-primary-color) (settings.primaryColor) — never buttonColor,
    // even when a distinct Button Color is configured. resolvedTheme.background
    // is primaryColor here (see BannerTheme.from's mapping), not .button.
    final spans = _parseMarkdownLinks(processedText, resolvedTheme.background, resolvedTheme.fontFamily);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 16,
      ),
      child: Text.rich(
        TextSpan(children: spans),
        textAlign: TextAlign.left,
        style: TextStyle(
          fontSize: fontSize,
          color: resolvedTheme.textMuted,
          fontFamily: resolvedTheme.fontFamily,
          height: 1.6,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
