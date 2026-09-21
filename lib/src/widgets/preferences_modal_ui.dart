/// PreferencesModalUI - `preferences_modal` banner template.
///
/// A simple stacked purpose-card list with three actions: "Only Necessary",
/// "Save My Preferences", and "Accept All". Unlike [BannerUI]'s action bar,
/// this template has no "Reject All" button (mirrors the NPM SDK's
/// `PreferencesModalUI.jsx`, which intentionally omits it).
import 'package:flutter/material.dart' hide Banner;
import '../models/banner.dart' as models;
import '../utils/i18n.dart';
import 'modern_banner_header.dart';
import 'modern_banner_footer.dart';
import 'modern_purpose_card.dart';

class PreferencesModalUI extends StatelessWidget {
  final models.Banner banner;
  final String companyName;
  final String? logoUrl;
  final Function(String, String) onChangePurpose;
  final VoidCallback onAcceptMandatory;
  final VoidCallback onAcceptSelected;
  final VoidCallback onConsentAll;
  final String? primaryColor;

  const PreferencesModalUI({
    super.key,
    required this.banner,
    required this.companyName,
    this.logoUrl,
    required this.onChangePurpose,
    required this.onAcceptMandatory,
    required this.onAcceptSelected,
    required this.onConsentAll,
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
                          onToggle: onChangePurpose,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton(
                        onPressed: onAcceptMandatory,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(I18n.t('accept_only_necessary')),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: onAcceptSelected,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: parsedPrimaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Save My Preferences',
                          style: TextStyle(color: parsedPrimaryColor),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: onConsentAll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: parsedPrimaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: Text(I18n.t('accept_all')),
                      ),
                    ],
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
