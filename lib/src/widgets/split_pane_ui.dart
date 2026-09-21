/// SplitPaneUI - `general_split_pane` banner template.
///
/// A selectable list of purposes on one side and a detail pane (description,
/// processing activities, data elements/processors) for the active purpose
/// on the other. On narrow screens the detail pane renders below the list
/// instead of beside it. Mirrors the NPM SDK's `SplitPaneUI.jsx`.
import 'package:flutter/material.dart' hide Banner;
import '../models/banner.dart' as models;
import '../utils/i18n.dart';
import 'modern_banner_header.dart';
import 'modern_banner_footer.dart';
import 'modern_banner_actions.dart';

class SplitPaneUI extends StatefulWidget {
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

  const SplitPaneUI({
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
  State<SplitPaneUI> createState() => _SplitPaneUIState();
}

class _SplitPaneUIState extends State<SplitPaneUI> {
  String? _activePurposeId;

  @override
  Widget build(BuildContext context) {
    final settings = widget.banner.bannerSettings;
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;
    final actionButtonText = settings?.actionButtonText ?? I18n.t('accept_all');
    final footerText = settings?.footerText ??
        'Review our [Privacy Policy] and [Transparency Centre], [DPO Details]. Use the [Rights Centre] anytime to withdraw consent, delete data, name a nominee, or raise a grievance.';

    final purposes = widget.banner.purposes;
    final activePurpose = purposes.firstWhere(
      (p) => p.id == _activePurposeId,
      orElse: () => purposes.isNotEmpty
          ? purposes.first
          : models.Purpose(
              id: '',
              name: '',
              description: '',
              isMandatory: false,
              consented: 'declined',
              expiryPeriod: '',
            ),
    );

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
              vertical: isMobile ? 16 : 20,
            ),
            child: purposes.isEmpty
                ? const SizedBox.shrink()
                : (isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildList(purposes),
                          const SizedBox(height: 16),
                          _buildDetail(activePurpose),
                        ],
                      )
                    : IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 220, child: _buildList(purposes)),
                            Container(width: 1, color: Colors.grey[200]),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: _buildDetail(activePurpose),
                              ),
                            ),
                          ],
                        ),
                      )),
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

  Widget _buildList(List<models.Purpose> purposes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: purposes.map((p) {
        final isActive = p.id == (_activePurposeId ?? purposes.first.id);
        return InkWell(
          onTap: () => setState(() => _activePurposeId = p.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: isActive ? Colors.grey[100] : null,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isActive ? Colors.grey[400]! : Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    p.name,
                    style: TextStyle(
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (p.isMandatory)
                  Container(
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
        );
      }).toList(),
    );
  }

  Widget _buildDetail(models.Purpose purpose) {
    if (purpose.id.isEmpty) return const SizedBox.shrink();
    final dataElements = purpose.dataElements ?? [];
    final legalEntities = purpose.legalEntities ?? [];
    final tools = purpose.tools ?? [];
    final processingActivities = purpose.processingActivities ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                purpose.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            if (!purpose.isMandatory && !purpose.isLegitimate)
              Switch(
                value: purpose.consented == 'accepted',
                onChanged: (value) => widget.onChangePurpose(
                  purpose.id,
                  value ? 'accepted' : 'declined',
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(purpose.description, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        if (processingActivities.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(I18n.t('processing_activities'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          ...processingActivities.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${a.name}', style: const TextStyle(fontSize: 13)),
              )),
        ],
        if (dataElements.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(I18n.t('data_elements'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: dataElements
                .map((e) => Chip(label: Text(e.name, style: const TextStyle(fontSize: 12))))
                .toList(),
          ),
        ],
        if (legalEntities.isNotEmpty || tools.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(I18n.t('data_processors'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...legalEntities.map((e) => e.name),
              ...tools.map((e) => e.name),
            ].map((name) => Chip(label: Text(name, style: const TextStyle(fontSize: 12)))).toList(),
          ),
        ],
      ],
    );
  }
}
