/// CompactListUI - `general_compact_list` banner template.
///
/// Accordion-style rows: one collapsed row per purpose (name, mandatory
/// badge, toggle), expanding to reveal description, expiry, and
/// Data Elements/Data Processors detail sections. Mirrors the NPM SDK's
/// `CompactListUI.jsx`.
import 'package:flutter/material.dart' hide Banner;
import '../models/banner.dart' as models;
import '../utils/i18n.dart';
import 'modern_banner_header.dart';
import 'modern_banner_footer.dart';
import 'modern_banner_actions.dart';
import 'collapsible_data_section.dart';

class CompactListUI extends StatefulWidget {
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

  const CompactListUI({
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
  State<CompactListUI> createState() => _CompactListUIState();
}

class _CompactListUIState extends State<CompactListUI> {
  final Set<String> _expandedIds = {};

  @override
  Widget build(BuildContext context) {
    final settings = widget.banner.bannerSettings;
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
              logoUrl: settings?.logoUrl ?? widget.logoUrl,
              orgName: widget.companyName,
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
              children: widget.banner.purposes
                  .map((p) => _buildRow(p, isMobile))
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
                    orgName: widget.companyName,
                  ),
                ),
                ModernBannerActions(
                  onRejectAll: widget.onRejectAll,
                  onConsentAll: widget.onConsentAll,
                  onAcceptSelected: widget.onAcceptSelected,
                  onAcceptMandatory: widget.onAcceptMandatory,
                  hasUserInteracted: widget.hasUserInteracted,
                  purposes: widget.banner.purposes,
                  actionButtonText: actionButtonText,
                  primaryColor: settings?.primaryColor ?? widget.primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(models.Purpose purpose, bool isMobile) {
    final isExpanded = _expandedIds.contains(purpose.id);
    final isAccepted = purpose.consented == 'accepted';
    final dataElements = purpose.dataElements ?? [];
    final legalEntities = purpose.legalEntities ?? [];
    final tools = purpose.tools ?? [];

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (isExpanded) {
                _expandedIds.remove(purpose.id);
              } else {
                _expandedIds.add(purpose.id);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
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
                  ),
                  if (!purpose.isMandatory && !purpose.isLegitimate)
                    Switch(
                      value: isAccepted,
                      onChanged: (value) => widget.onChangePurpose(
                        purpose.id,
                        value ? 'accepted' : 'declined',
                      ),
                    ),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    purpose.description,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  if (dataElements.isNotEmpty)
                    CollapsibleDataSection(
                      title: I18n.t('data_elements'),
                      items: dataElements,
                      isOpen: true,
                      onToggle: () {},
                    ),
                  if (legalEntities.isNotEmpty || tools.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    CollapsibleDataSection(
                      title: I18n.t('data_processors'),
                      items: [...legalEntities, ...tools],
                      isOpen: true,
                      onToggle: () {},
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
