/// ModernPurposeCard - Flutter purpose card widget
import 'package:flutter/material.dart' hide Banner;
import '../models/banner.dart' as models;
import '../utils/i18n.dart';
import '../services/banner_theme.dart';
import 'collapsible_data_section.dart';

class ModernPurposeCard extends StatefulWidget {
  final models.Purpose purpose;
  final models.Banner banner;
  final Function(String, String) onToggle;
  final bool readOnly;
  final BannerTheme? theme;
  /// Translates dynamic (server-supplied) text via the banner's translation
  /// snapshot. Identity function if omitted.
  final String Function(String)? translate;

  const ModernPurposeCard({
    super.key,
    required this.purpose,
    required this.banner,
    required this.onToggle,
    this.readOnly = false,
    this.theme,
    this.translate,
  });

  @override
  State<ModernPurposeCard> createState() => _ModernPurposeCardState();
}

class _ModernPurposeCardState extends State<ModernPurposeCard> {
  String? _openSection;

  String _localize(String text) => (widget.translate ?? (t) => t)(text);

  /// For static UI microcopy (badges, section titles): prefer the
  /// server-driven snapshot (covers every language the admin actually
  /// configured, matching truKIT-NPM's translateDynamic usage for this exact
  /// same copy), falling back to the static I18n bundle (only covers
  /// en/hi/ta) so those two languages keep working even with no snapshot.
  String _tr(String text, [String? i18nKey]) {
    final snapshotResult = widget.translate != null ? widget.translate!(text) : text;
    if (snapshotResult != text) return snapshotResult;
    return i18nKey != null ? I18n.t(i18nKey) : text;
  }

  void _toggleSection(String section) {
    setState(() {
      _openSection = _openSection == section ? null : section;
    });
  }

  String get _expiryText {
    final label = widget.purpose.expiryLabel;
    if (label != null && label.trim().isNotEmpty) return label;

    final period = widget.purpose.expiryPeriod.trim();
    if (period.isEmpty) return '';

    final lower = period.toLowerCase();
    if (lower == 'one_time' || lower == 'one_off' || lower == 'never') {
      return 'Until withdrawn';
    }
    // UUID-shaped values are internal references (e.g. to another purpose),
    // not human-readable durations.
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    if (uuidPattern.hasMatch(period)) return 'Until withdrawn';

    return period;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: I18n.localeNotifier,
      builder: (context, locale, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = widget.theme ?? const BannerTheme(
      background: Color(0xFFFFFFFF),
      text: Color(0xFF111827),
      textMuted: Color(0xFF6B7280),
      button: Color(0xFF3B82F6),
      buttonText: Color(0xFFFFFFFF),
      border: Color(0xFFE5E7EB),
      fontSize: 16,
    );
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    final isAccepted = widget.purpose.consented == 'accepted';
    final dataElements = widget.purpose.dataElements ?? [];
    final processingActivities = widget.purpose.processingActivities ?? [];
    // Matches truKIT-NPM's ModernPurposeCard.jsx: legal entities and tools
    // are combined into a single flat "Data Processors" list, not split
    // into two labeled subsections.
    final dataProcessors = [
      ...(widget.purpose.legalEntities ?? []),
      ...(widget.purpose.tools ?? []),
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.border, width: 1.5),
        borderRadius: BorderRadius.circular(12),
        color: theme.background,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Purpose Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with Mandatory badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _localize(widget.purpose.name),
                            style: TextStyle(
                              fontSize: isMobile ? 15 : 16,
                              fontWeight: FontWeight.w700,
                              color: theme.text,
                              fontFamily: theme.fontFamily,
                            ),
                          ),
                        ),
                        if (widget.purpose.isMandatory)
                          Container(
                            margin: EdgeInsets.only(left: isMobile ? 6 : 8),
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 6 : 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              border: Border.all(
                                color: Colors.red[400]!,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _tr('Necessary', 'necessary_group'),
                              style: TextStyle(
                                fontSize: isMobile ? 9 : 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.red[700],
                                fontFamily: theme.fontFamily,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 6 : 8),
                    // Description
                    Text(
                      _localize(widget.purpose.description),
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: theme.textMuted,
                        fontFamily: theme.fontFamily,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: isMobile ? 8 : 12),
                    // Expiry info
                    if (_expiryText.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.background,
                          border: Border.all(color: theme.border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Expires: $_expiryText',
                          style: TextStyle(
                            fontSize: isMobile ? 10 : 12,
                            color: theme.text,
                            fontWeight: FontWeight.w500,
                            fontFamily: theme.fontFamily,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: isMobile ? 8 : 12),
              // Toggle Switch — matches truKIT-NPM's ModernPurposeCard.jsx: a
              // Legitimate Interest purpose has no accept/decline concept, so
              // nothing renders here at all, not even a disabled switch.
              if (!widget.purpose.isLegitimate)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Transform.scale(
                      scale: isMobile ? 0.8 : 1.0,
                      // Material3's Switch renders a visibly larger thumb when
                      // selected than when unselected (its own spec, not
                      // something thumbColor/trackColor control) — that made
                      // the "same thumb color/size on and off" parity fix
                      // above look inconsistent between states. Material2's
                      // Switch keeps a constant thumb size in both states,
                      // matching truKIT-NPM's plain CSS toggle exactly.
                      child: Theme(
                        data: ThemeData(
                          useMaterial3: false,
                          brightness: Theme.of(context).brightness,
                        ),
                        child: Switch(
                          value: isAccepted,
                          // Matches truKIT-NPM/truKIT-react-native: mandatory purposes stay
                          // interactive — declining one is caught by the H-Case intercept at
                          // submit time, not prevented here.
                          onChanged: widget.readOnly
                              ? null
                              : (value) {
                                  widget.onToggle(
                                    widget.purpose.id,
                                    value ? 'accepted' : 'declined',
                                  );
                                },
                          // Uses WidgetStateProperty (not the activeThumbColor/
                          // activeTrackColor shorthand) so a mandatory purpose's
                          // switch looks identical whether interactive or read-only —
                          // the shorthand params don't apply to the disabled state.
                          // Matches truKIT-NPM's .thumb/.track exactly: the thumb is
                          // the same color on and off (the primary BUTTON text
                          // color, not the body text color — the track alone
                          // carries the on/off signal via its own color change).
                          thumbColor: WidgetStatePropertyAll<Color>(theme.buttonText),
                          trackColor: WidgetStateProperty.resolveWith<Color>(
                            (states) => states.contains(WidgetState.selected)
                                ? theme.button
                                : theme.border,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      isAccepted ? 'Accepted' : 'Declined',
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 11,
                        fontWeight: FontWeight.w600,
                        color: isAccepted ? Colors.green[700] : theme.textMuted,
                        fontFamily: theme.fontFamily,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Data Elements Section
          if (dataElements.isNotEmpty) ...[
            SizedBox(height: isMobile ? 10 : 12),
            CollapsibleDataSection(
              title: _tr('Data Elements', 'data_elements'),
              items: dataElements,
              isOpen: _openSection == 'data_elements',
              onToggle: () => _toggleSection('data_elements'),
              translate: widget.translate,
              theme: theme,
            ),
          ],

          // Data Processors Section — matches truKIT-NPM's
          // ModernPurposeCard.jsx: legal entities and tools are combined
          // into a single flat "Data Processors" list, not split into two
          // labeled subsections.
          if (dataProcessors.isNotEmpty) ...[
            SizedBox(height: isMobile ? 8 : 12),
            CollapsibleDataSection(
              title: _tr('Data Processors', 'data_processors'),
              items: dataProcessors,
              isOpen: _openSection == 'data_processors',
              onToggle: () => _toggleSection('data_processors'),
              translate: widget.translate,
              theme: theme,
            ),
          ],

          // Processing Activities Section
          if (processingActivities.isNotEmpty) ...[
            SizedBox(height: isMobile ? 8 : 12),
            CollapsibleDataSection(
              title: _tr('Processing Activities', 'processing_activities'),
              items: processingActivities,
              isOpen: _openSection == 'processing_activities',
              onToggle: () => _toggleSection('processing_activities'),
              translate: widget.translate,
              theme: theme,
            ),
          ],
        ],
      ),
    );
  }
}
