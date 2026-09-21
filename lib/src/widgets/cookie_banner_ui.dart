import 'package:flutter/material.dart' hide Banner;
import '../models/banner.dart' as models;

/// Cookie consent banner UI widget.
///
/// Displays a cookie-specific consent banner with expandable sections for
/// purposes, data elements, and processing activities. Used for cookie consent
/// collection flows.
///
/// Example:
/// ```dart
/// CookieBannerUI(
///   banner: bannerData,
///   companyName: 'My Company',
///   onRejectAll: () => print('Rejected all cookies'),
///   onConsentAll: () => print('Consented to all cookies'),
/// )
/// ```
class CookieBannerUI extends StatefulWidget {
  /// Banner configuration data from the API
  final models.Banner banner;
  
  /// Company name to display in the banner
  final String companyName;
  
  /// Optional company logo URL
  final String? logoUrl;
  
  /// Callback when user clicks "Reject All"
  final VoidCallback onRejectAll;
  
  /// Callback when user clicks "Consent All"
  final VoidCallback onConsentAll;
  
  /// Optional primary color for buttons (hex format)
  final String? primaryColor;
  
  /// Optional secondary color (hex format)
  final String? secondaryColor;

  /// Creates a CookieBannerUI widget.
  const CookieBannerUI({
    super.key,
    required this.banner,
    required this.companyName,
    this.logoUrl,
    required this.onRejectAll,
    required this.onConsentAll,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  State<CookieBannerUI> createState() => _CookieBannerUIState();
}

class _CookieBannerUIState extends State<CookieBannerUI> {
  final Map<String, bool> _expandedSections = {
    'purposes': true,
    'dataElements': false,
    'activities': false,
  };

  void _toggleSection(String section) {
    setState(() {
      _expandedSections[section] = !_expandedSections[section]!;
    });
  }

  @override
  Widget build(BuildContext context) {
    final purposes = widget.banner.purposes;
    final dataElements = widget.banner.dataElements ?? [];
    final processingActivities = widget.banner.processingActivities ?? [];
    final primaryColor = widget.primaryColor ?? '#16a34a';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.banner.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Cookie',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.banner.title.isNotEmpty)
              const SizedBox(height: 8),
            if (widget.banner.title.isNotEmpty)
              Text(
                widget.banner.title,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            const SizedBox(height: 24),
            if (purposes.isNotEmpty)
              _AccordionSection(
                title: 'Purposes for Data Collection',
                count: purposes.length,
                isExpanded: _expandedSections['purposes']!,
                onToggle: () => _toggleSection('purposes'),
                child: Column(
                  children: purposes
                      .map((p) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.only(left: 12),
                            decoration: const BoxDecoration(
                              border: Border(left: BorderSide(color: Colors.blue, width: 4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (p.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    p.description,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            if (dataElements.isNotEmpty) ...[
              const SizedBox(height: 12),
              _AccordionSection(
                title: 'Data Elements Collected',
                count: dataElements.length,
                isExpanded: _expandedSections['dataElements']!,
                onToggle: () => _toggleSection('dataElements'),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: dataElements
                      .map((de) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              de.name,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
            if (processingActivities.isNotEmpty) ...[
              const SizedBox(height: 12),
              _AccordionSection(
                title: 'Processing Activities',
                count: processingActivities.length,
                isExpanded: _expandedSections['activities']!,
                onToggle: () => _toggleSection('activities'),
                child: Column(
                  children: processingActivities
                      .map((activity) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.purple,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  activity.name,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: widget.onConsentAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _parseColor(primaryColor),
                  ),
                  child: const Text('Accept All'),
                ),
                OutlinedButton(
                  onPressed: widget.onRejectAll,
                  child: const Text('Reject All'),
                ),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _expandedSections['purposes'] = true;
                      _expandedSections['dataElements'] = true;
                      _expandedSections['activities'] = true;
                    });
                  },
                  child: const Text('Manage Preferences'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.green;
    }
  }
}

class _AccordionSection extends StatelessWidget {
  final String title;
  final int? count;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;

  const _AccordionSection({
    required this.title,
    this.count,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(8),
                  topRight: const Radius.circular(8),
                  bottomLeft: isExpanded ? Radius.zero : const Radius.circular(8),
                  bottomRight: isExpanded ? Radius.zero : const Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        count.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
        ],
      ),
    );
  }
}

