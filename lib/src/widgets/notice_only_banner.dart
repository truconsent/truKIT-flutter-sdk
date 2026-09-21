/// NoticeOnlyBanner - `notice_only` banner template.
///
/// Renders every purpose as a read-only card (no toggles) with a single
/// "I Understand" acknowledgement button. Unlike [BannerUI]'s notice-only
/// case (which is derived from purpose composition), selecting this template
/// forces the read-only/acknowledge-only presentation regardless of what
/// purposes are present, mirroring the NPM SDK's dedicated
/// `NoticeOnlyBanner.jsx` component.
import 'package:flutter/material.dart' hide Banner;
import '../models/banner.dart' as models;
import 'modern_banner_header.dart';
import 'modern_banner_footer.dart';
import 'modern_purpose_card.dart';

class NoticeOnlyBanner extends StatelessWidget {
  final models.Banner banner;
  final String companyName;
  final String? logoUrl;
  final VoidCallback onAcknowledge;
  final String? primaryColor;

  const NoticeOnlyBanner({
    super.key,
    required this.banner,
    required this.companyName,
    this.logoUrl,
    required this.onAcknowledge,
    this.primaryColor,
  });

  Color _parseColor(String? colorString) {
    if (colorString == null) return const Color(0xFF3b82f6);
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF3b82f6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = banner.bannerSettings;
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;
    final parsedPrimaryColor =
        _parseColor(settings?.primaryColor ?? primaryColor ?? '#3b82f6');
    final footerText = settings?.footerText ??
        'Review our [Privacy Policy] and [Transparency Centre], [DPO Details]. Use the [Rights Centre] anytime to withdraw consent, delete data, name a nominee, or raise a grievance.';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.purple.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: ModernBannerHeader(
              logoUrl: settings?.logoUrl ?? logoUrl,
              orgName: companyName,
              bannerTitle: settings?.bannerTitle,
              disclaimerText: settings?.disclaimerText,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 24,
              vertical: isMobile ? 16 : 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: banner.purposes
                  .map((p) => Padding(
                        padding: EdgeInsets.only(bottom: isMobile ? 10 : 12),
                        child: ModernPurposeCard(
                          purpose: p,
                          banner: banner,
                          onToggle: (_, __) {},
                          readOnly: true,
                        ),
                      ))
                  .toList(),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 24,
                    vertical: isMobile ? 12 : 16,
                  ),
                  child: ModernBannerFooter(
                    footerText: footerText,
                    orgName: companyName,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 24,
                    vertical: isMobile ? 12 : 16,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onAcknowledge,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: parsedPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'I Understand',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
