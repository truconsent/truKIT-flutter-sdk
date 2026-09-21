/// InlineSingleRowUI - `inline_single_row` banner template.
///
/// One row per purpose with all its detail (description, data elements,
/// data processors, expiry, toggle) visible at once — no expand/collapse,
/// unlike [CompactListUI]. Mirrors the NPM SDK's `InlineSingleRowUI.jsx`
/// (a spreadsheet/table-like layout). Returns an empty widget if there are
/// no purposes, matching the NPM behavior.
import 'package:flutter/material.dart' hide Banner;
import '../models/banner.dart' as models;
import '../utils/i18n.dart';
import 'modern_banner_header.dart';
import 'modern_banner_footer.dart';
import 'modern_banner_actions.dart';

class InlineSingleRowUI extends StatelessWidget {
  final models.Banner banner;
  final String companyName;
  final String? logoUrl;
  final Function(String, String) onChangePurpose;
  final VoidCallback onRejectAll;
  final VoidCallback onConsentAll;
  final VoidCallback onAcceptSelected;
  final VoidCallback onAcceptMandatory;
  final bool hasUserInteracted;
  final String? primaryColor;

  const InlineSingleRowUI({
    super.key,
    required this.banner,
    required this.companyName,
    this.logoUrl,
    required this.onChangePurpose,
    required this.onRejectAll,
    required this.onConsentAll,
    required this.onAcceptSelected,
    required this.onAcceptMandatory,
    this.hasUserInteracted = false,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (banner.purposes.isEmpty) return const SizedBox.shrink();

    final settings = banner.bannerSettings;
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;
    final actionButtonText = settings?.actionButtonText ?? I18n.t('accept_all');
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
              vertical: isMobile ? 12 : 16,
            ),
            child: Column(
              children:
                  banner.purposes.map((p) => _buildRow(p, isMobile)).toList(),
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
                ModernBannerActions(
                  onRejectAll: onRejectAll,
                  onConsentAll: onConsentAll,
                  onAcceptSelected: onAcceptSelected,
                  onAcceptMandatory: onAcceptMandatory,
                  hasUserInteracted: hasUserInteracted,
                  purposes: banner.purposes,
                  actionButtonText: actionButtonText,
                  primaryColor: settings?.primaryColor ?? primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(models.Purpose purpose, bool isMobile) {
    final dataElements = purpose.dataElements ?? [];
    final processors = [
      ...?purpose.legalEntities?.map((e) => e.name),
      ...?purpose.tools?.map((e) => e.name),
    ];
    final expiryText = purpose.expiryLabel?.isNotEmpty == true
        ? purpose.expiryLabel!
        : purpose.expiryPeriod;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 10 : 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            purpose.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                        if (purpose.isMandatory)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              I18n.t('mandatory'),
                              style: TextStyle(fontSize: 9, color: Colors.red[700]),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(purpose.description,
                        style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  ],
                ),
              ),
              if (!purpose.isMandatory && !purpose.isLegitimate)
                Switch(
                  value: purpose.consented == 'accepted',
                  onChanged: (value) =>
                      onChangePurpose(purpose.id, value ? 'accepted' : 'declined'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (dataElements.isNotEmpty)
                _buildColumn(I18n.t('data_elements'), dataElements.map((e) => e.name)),
              if (processors.isNotEmpty)
                _buildColumn(I18n.t('data_processors'), processors),
              _buildColumn('Expiry', [expiryText.isEmpty ? '—' : expiryText]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColumn(String title, Iterable<String> values) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 100, maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey[500],
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            values.join(', '),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
