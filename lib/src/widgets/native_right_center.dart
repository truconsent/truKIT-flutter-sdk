import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/rights_center_api.dart';

Color _hexToColor(String hex) {
  final clean = hex.replaceAll('#', '');
  final full = clean.length == 6 ? 'FF$clean' : clean;
  return Color(int.parse(full, radix: 16));
}

/// Native Flutter implementation of Rights Center.
///
/// Provides a comprehensive rights management interface with native tabs for:
/// - Consent: View and manage all consent records
/// - Rights: Exercise data rights (access, deletion)
/// - Nominee: Appoint and manage nominees
/// - Grievance: Submit and view grievance tickets
/// - Transparency: View transparency information
/// - DPO: Data Protection Officer contact information
///
/// Tabs are shown/hidden based on [RightsCenterSettings] fetched from the API.
///
/// Example:
/// ```dart
/// NativeRightCenter(
///   userId: 'user-123',
///   apiKey: 'your-api-key',
///   organizationId: 'your-org-id',
///   apiUrl: 'https://trukit-dev.truconsent.io',
/// )
/// ```
class NativeRightCenter extends StatefulWidget {
  /// The signed-in user's id (SSO mode). Omit this when the Rights Center's
  /// global settings have `access_mode: 'non_sso'` — in that case the widget
  /// itself authenticates the user via a phone + OTP flow before showing any
  /// tab content, and the resulting data principal id is used in its place.
  final String? userId;
  final String? apiKey;
  final String? organizationId;
  final String? apiUrl;
  final String? assetId;
  final String? authToken;

  const NativeRightCenter({
    super.key,
    this.userId,
    this.apiKey,
    this.organizationId,
    this.apiUrl,
    this.assetId,
    this.authToken,
  });

  @override
  State<NativeRightCenter> createState() => _NativeRightCenterState();
}

class _NativeRightCenterState extends State<NativeRightCenter> {
  late RightsCenterApi _api;

  // Theme helpers — derived from _settings after fetch
  Color get _bgColor => _hexToColor(_settings.backgroundColor);
  Color get _primaryText => _hexToColor(_settings.primaryTextColor);
  Color get _secondaryText => _hexToColor(_settings.secondaryTextColor);
  Color get _btnColor => _hexToColor(_settings.buttonColor);
  Color get _btnTextColor => _hexToColor(_settings.buttonTextColor);
  // Matches truKIT-react-native's deriveThemeColors: border = secondaryText @ 45% alpha.
  Color get _borderColor => _secondaryText.withValues(alpha: 0.45);
  // Matches truKIT-react-native's deriveThemeColors: infoBg/infoBorder =
  // button color @ 12%/25% alpha — used by the Grievance chat's Open status
  // pill.
  Color get _infoBg => _btnColor.withValues(alpha: 0.12);
  Color get _infoBorder => _btnColor.withValues(alpha: 0.25);
  // Matches truKIT-react-native's deriveThemeColors fixed success colors —
  // used by the Grievance chat's Resolved status pill.
  static const Color _successBg = Color(0x2E22C55E); // rgba(34,197,94,0.18)
  static const Color _successText = Color(0xFF166534);

  // Global
  bool _isInitializing = true;
  RightsCenterSettings _settings = RightsCenterSettings.defaults;
  String _activeTab = 'Consent';

  // Consent
  List<Map<String, dynamic>> _consents = [];
  Map<String, String> _initialConsents = {};
  bool _consentsLoading = false;
  bool _dirty = false;
  Set<String> _changedPurposeIds = {};
  bool _showSaveSuccess = false;

  // Rights
  bool _showAccessModal = false;
  bool _showDeleteModal = false;
  bool _accessConfirmed = false;
  bool _deleteConfirmed = false;

  // DPO
  DPOInfo? _dpoInfo;

  // Nominee
  List<Nominee> _nominees = [];
  bool _editing = false;
  final _nomineeFormKey = GlobalKey<FormState>();
  final Map<String, String> _nomineeForm = {
    'nominee_name': '',
    'relationship': '',
    'nominee_email': '',
    'nominee_mobile': '',
    'purpose_of_appointment': '',
  };

  // Grievance
  List<GrievanceTicket> _tickets = [];
  bool _showGrievanceForm = false;
  final _grievanceFormKey = GlobalKey<FormState>();
  final Map<String, String> _grievanceForm = {
    'subject': '',
    'category': '',
    'description': '',
  };
  String? _openTicketId;
  List<GrievanceMessage> _chatMessages = [];
  bool _chatLoading = false;
  bool _chatSending = false;
  final _chatInputController = TextEditingController();
  final _chatScrollController = ScrollController();
  WebSocketChannel? _chatChannel;
  Timer? _chatPollTimer;
  bool _chatLive = false;

  // Non-SSO OTP auth
  OtpVerifyResult? _internalAuth;
  bool _nonSsoDismissed = false;
  bool _otpSending = false;
  bool _otpVerifying = false;
  String? _otpError;
  bool _otpSent = false;
  int _otpResendsUsed = 0;
  int _otpCooldownSeconds = 0;
  Timer? _otpCooldownTimer;
  final _phoneController = TextEditingController();
  final _countryCodeController = TextEditingController(text: '+91');
  final _otpController = TextEditingController();

  /// The user id to act as: the SSO-supplied [NativeRightCenter.userId], or
  /// (once verified) the non-SSO OTP flow's data principal id.
  String get _effectiveUserId => widget.userId ?? _internalAuth?.dataPrincipalId ?? '';

  /// True while non-SSO access is configured, no SSO userId was supplied, and
  /// the user hasn't completed OTP verification yet. Used to gate data
  /// fetching (regardless of whether the OTP UI is currently visible or has
  /// been dismissed) — mirrors the NPM SDK's `isNonSsoAccess`/bootstrap gate.
  bool get _needsNonSsoAuth =>
      (widget.userId == null || widget.userId!.isEmpty) &&
      _settings.accessMode == 'non_sso' &&
      _internalAuth == null;

  /// True when the phone/OTP screen should actually be rendered: same as
  /// [_needsNonSsoAuth], but also respects the user dismissing it (the "X"
  /// close button) — mirrors the NPM SDK's `showNonSsoModal`.
  bool get _showOtpGate => _needsNonSsoAuth && !_nonSsoDismissed;

  /// True when access is SSO (the default — any `access_mode` other than
  /// `'non_sso'`) but no identity has been resolved at all: the integrating
  /// app simply never supplied a userId. Mirrors the NPM SDK's condition for
  /// showing "Please log in to view your Rights Center." instead of empty/
  /// broken tab content.
  bool get _needsSsoLogin =>
      (widget.userId == null || widget.userId!.isEmpty) &&
      _internalAuth == null &&
      _settings.accessMode != 'non_sso';

  /// Non-SSO sessions are read-only in the Consent tab per the NPM SDK: only
  /// purposes with a genuine logged decision are shown, and toggles are
  /// hidden.
  bool get _isNonSsoReadOnly =>
      (widget.userId == null || widget.userId!.isEmpty) && _internalAuth != null;

  @override
  void initState() {
    super.initState();
    _api = RightsCenterApi(
      apiUrl: widget.apiUrl ?? 'https://trukit-dev.truconsent.io',
      apiKey: widget.apiKey ?? '',
      organizationId: widget.organizationId ?? '',
      userId: widget.userId,
      authToken: widget.authToken,
    );
    _bootstrap();
  }

  @override
  void didUpdateWidget(NativeRightCenter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Without this, a parent rebuilding with a different `userId` (e.g. a
    // login completing while this screen is already open, upgrading from
    // guest/non-SSO to an authenticated SSO identity) would silently keep
    // showing data fetched under the old identity forever, since `_bootstrap`
    // otherwise only ever runs once from `initState`.
    final identityChanged = oldWidget.userId != widget.userId ||
        oldWidget.apiKey != widget.apiKey ||
        oldWidget.organizationId != widget.organizationId ||
        oldWidget.apiUrl != widget.apiUrl ||
        oldWidget.assetId != widget.assetId ||
        oldWidget.authToken != widget.authToken;
    if (identityChanged) {
      _api = RightsCenterApi(
        apiUrl: widget.apiUrl ?? 'https://trukit-dev.truconsent.io',
        apiKey: widget.apiKey ?? '',
        organizationId: widget.organizationId ?? '',
        userId: widget.userId,
        authToken: widget.authToken,
      );
      // A brand-new (non-null) userId from the parent supersedes any
      // in-progress non-SSO OTP session tied to the old (null/guest) identity.
      if (widget.userId != null && widget.userId!.isNotEmpty) {
        _internalAuth = null;
      }
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _otpCooldownTimer?.cancel();
    _chatPollTimer?.cancel();
    _chatChannel?.sink.close();
    _phoneController.dispose();
    _countryCodeController.dispose();
    _otpController.dispose();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _isInitializing = true);
    // Settings must be fetched first: they determine whether non-SSO OTP
    // auth is required before any other (user-scoped) data can be fetched.
    await _fetchSettings();
    if (_needsNonSsoAuth) {
      if (mounted) setState(() => _isInitializing = false);
      return;
    }
    final fetches = [_fetchDPO()];
    // Nominees/tickets/consents are user-scoped; skip them entirely when no
    // identity has been resolved (SSO mode, signed-out visitor) rather than
    // firing requests that can only fail.
    if (_effectiveUserId.isNotEmpty) {
      fetches.addAll([_fetchNominees(), _fetchTickets(), _fetchUserConsents()]);
    }
    await Future.wait(fetches);
    if (mounted) setState(() => _isInitializing = false);
  }

  Future<void> _fetchSettings() async {
    try {
      final s = await _api.getRightsCenterSettings(assetId: widget.assetId);
      if (mounted) setState(() => _settings = s);
    } catch (e) {
      debugPrint('[NativeRightCenter] fetchSettings error: $e');
    }
  }

  Future<void> _fetchUserConsents() async {
    if (mounted) setState(() => _consentsLoading = true);
    try {
      final list = await _api.getUserConsentsFlat(
        _effectiveUserId,
        assetId: widget.assetId,
      );
      if (mounted) {
        setState(() {
          _consents = list;
          _initialConsents = {
            for (final p in list) p['id'].toString(): p['consented'].toString()
          };
          _dirty = false;
          _changedPurposeIds = {};
        });
      }
    } catch (e) {
      debugPrint('[NativeRightCenter] fetchUserConsents error: $e');
      if (mounted) setState(() => _consents = []);
    } finally {
      if (mounted) setState(() => _consentsLoading = false);
    }
  }

  // ─── Non-SSO OTP auth ─────────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _otpError = 'Enter a phone number');
      return;
    }
    setState(() {
      _otpSending = true;
      _otpError = null;
    });
    try {
      await _api.sendOtp(
        phone: phone,
        countryCode: _countryCodeController.text.trim(),
        assetId: widget.assetId,
      );
      if (mounted) {
        setState(() {
          _otpSent = true;
          _otpCooldownSeconds = 30;
        });
        _startOtpCooldown();
      }
    } catch (e) {
      if (mounted) setState(() => _otpError = 'Failed to send OTP. Please try again.');
    } finally {
      if (mounted) setState(() => _otpSending = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_otpResendsUsed >= 3 || _otpCooldownSeconds > 0) return;
    setState(() => _otpResendsUsed += 1);
    await _sendOtp();
  }

  void _startOtpCooldown() {
    _otpCooldownTimer?.cancel();
    _otpCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _otpCooldownSeconds = (_otpCooldownSeconds - 1).clamp(0, 30);
      });
      if (_otpCooldownSeconds <= 0) timer.cancel();
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      setState(() => _otpError = 'Enter the OTP you received');
      return;
    }
    setState(() {
      _otpVerifying = true;
      _otpError = null;
    });
    try {
      final result = await _api.verifyOtp(
        phone: _phoneController.text.trim(),
        countryCode: _countryCodeController.text.trim(),
        otp: otp,
        assetId: widget.assetId,
      );
      if (mounted) {
        setState(() => _internalAuth = result);
        await _bootstrap();
      }
    } catch (e) {
      if (mounted) setState(() => _otpError = 'Incorrect or expired OTP. Please try again.');
    } finally {
      if (mounted) setState(() => _otpVerifying = false);
    }
  }

  Future<void> _fetchDPO() async {
    try {
      final info = await _api.getDPOInfo();
      if (mounted) setState(() => _dpoInfo = info);
    } catch (e) {
      debugPrint('[NativeRightCenter] fetchDPO error: $e');
    }
  }

  Future<void> _fetchNominees() async {
    try {
      final data = await _api.getNominees(_effectiveUserId);
      if (mounted) {
        setState(() {
          _nominees = data;
          if (data.isNotEmpty) {
            final n = data.first;
            _nomineeForm['nominee_name'] = n.nominee_name;
            _nomineeForm['relationship'] = n.relationship;
            _nomineeForm['nominee_email'] = n.nominee_email;
            _nomineeForm['nominee_mobile'] = n.nominee_mobile;
            _nomineeForm['purpose_of_appointment'] = n.purpose_of_appointment ?? '';
          }
        });
      }
    } catch (e) {
      debugPrint('[NativeRightCenter] fetchNominees error: $e');
      if (mounted) setState(() => _nominees = []);
    }
  }

  Future<void> _fetchTickets() async {
    try {
      final data = await _api.getGrievanceTickets(_effectiveUserId);
      if (mounted) setState(() => _tickets = data);
    } catch (e) {
      debugPrint('[NativeRightCenter] fetchTickets error: $e');
      if (mounted) setState(() => _tickets = []);
    }
  }

  // ─── Consent handlers ────────────────────────────────────────────────────────

  void _toggleConsent(String id) {
    setState(() {
      _consents = _consents.map((p) {
        if (p['id'].toString() == id) {
          final cur = p['consented'] == 'accepted' ? 'declined' : 'accepted';
          return {...p, 'consented': cur};
        }
        return p;
      }).toList();

      // Track changed vs initial
      final cur = _consents.firstWhere((p) => p['id'].toString() == id)['consented'];
      final initial = _initialConsents[id] ?? 'declined';
      if (cur != initial) {
        _changedPurposeIds.add(id);
      } else {
        _changedPurposeIds.remove(id);
      }
      _dirty = _changedPurposeIds.isNotEmpty;
    });
  }

  Future<void> _saveConsents() async {
    try {
      final changed = _consents
          .where((p) => _changedPurposeIds.contains(p['id'].toString()))
          .map((p) => Map<String, dynamic>.from(p))
          .toList();

      await _api.saveConsentToRightsCenter(
        _effectiveUserId,
        changed,
        assetId: widget.assetId,
      );

      setState(() {
        _dirty = false;
        _changedPurposeIds = {};
        _showSaveSuccess = true;
        _initialConsents = {
          for (final p in _consents) p['id'].toString(): p['consented'].toString()
        };
      });

      // Hide success banner after 3 s
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showSaveSuccess = false);
      });

      await _fetchUserConsents();
    } catch (e) {
      debugPrint('[NativeRightCenter] saveConsents error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save consent changes. Please try again.')),
        );
      }
    }
  }

  // ─── Rights handlers ─────────────────────────────────────────────────────────

  Future<void> _requestAccess() async {
    debugPrint('[NativeRightCenter] createAccessRequest userId="$_effectiveUserId"');
    try {
      await _api.createAccessRequest(_effectiveUserId, assetId: widget.assetId);
      if (mounted) {
        setState(() => _accessConfirmed = true);
        // Auto-close after showing the success state, matching truKIT-NPM/RN's timing —
        // the request buttons stay visible throughout, this only closes the dialog.
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _showAccessModal = false);
        });
      }
    } catch (e) {
      debugPrint('[NativeRightCenter] createAccessRequest error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit access request. Please try again.')),
        );
      }
    }
  }

  Future<void> _requestDeletion() async {
    debugPrint('[NativeRightCenter] createDeletionRequest userId="$_effectiveUserId"');
    try {
      await _api.createDeletionRequest(_effectiveUserId, assetId: widget.assetId);
      if (mounted) {
        setState(() => _deleteConfirmed = true);
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _showDeleteModal = false);
        });
      }
    } catch (e) {
      debugPrint('[NativeRightCenter] createDeletionRequest error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit deletion request. Please try again.')),
        );
      }
    }
  }

  // ─── Nominee handlers ─────────────────────────────────────────────────────────

  Future<void> _submitNominee() async {
    if (!_nomineeFormKey.currentState!.validate()) return;
    final nominee = _nominees.isNotEmpty ? _nominees.first : null;
    final payload = Nominee(
      nominee_name: _nomineeForm['nominee_name']!,
      relationship: _nomineeForm['relationship']!,
      nominee_email: _nomineeForm['nominee_email']!,
      nominee_mobile: _nomineeForm['nominee_mobile']!,
      purpose_of_appointment: _nomineeForm['purpose_of_appointment']?.isEmpty ?? true
          ? null
          : _nomineeForm['purpose_of_appointment'],
    );

    try {
      if (nominee != null && _editing && nominee.id != null) {
        final updated = await _api.updateNominee(nominee.id!, payload);
        setState(() {
          _nominees = [updated];
          _editing = false;
        });
      } else {
        final created = await _api.createNominee(payload, _effectiveUserId);
        setState(() => _nominees = [created]);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nominee saved successfully')),
        );
      }
    } catch (e) {
      debugPrint('[NativeRightCenter] submitNominee error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save nominee. Please try again.')),
        );
      }
    }
  }

  Future<void> _deleteNominee() async {
    final nominee = _nominees.isNotEmpty ? _nominees.first : null;
    if (nominee?.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Nominee'),
        content: const Text('Are you sure you want to delete this nominee?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _api.deleteNominee(nominee!.id!);
        setState(() {
          _nominees = [];
          _nomineeForm.updateAll((_, __) => '');
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nominee deleted successfully')),
          );
        }
      } catch (e) {
        debugPrint('[NativeRightCenter] deleteNominee error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete nominee. Please try again.')),
          );
        }
      }
    }
  }

  // ─── Grievance handlers ───────────────────────────────────────────────────────

  Future<void> _submitGrievance() async {
    if (!_grievanceFormKey.currentState!.validate()) return;

    final ticket = GrievanceTicket(
      subject: _grievanceForm['subject']!,
      category: _grievanceForm['category']!,
      description: _grievanceForm['description']!,
    );

    try {
      final created = await _api.createGrievanceTicket(ticket, _effectiveUserId);
      setState(() {
        _tickets = [created, ..._tickets];
        _showGrievanceForm = false;
        _grievanceForm.updateAll((_, __) => '');
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grievance ticket created successfully')),
        );
      }
    } catch (e) {
      debugPrint('[NativeRightCenter] submitGrievance error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create grievance ticket. Please try again.')),
        );
      }
    }
  }

  // ─── Grievance chat ───────────────────────────────────────────────────────────

  Future<void> _openTicket(GrievanceTicket ticket) async {
    final ticketId = ticket.ticket_id ?? ticket.id;
    if (ticketId == null) return;
    setState(() {
      _openTicketId = ticketId;
      _chatMessages = [];
      _chatLoading = true;
      _chatLive = false;
    });
    await _fetchChatMessages(ticketId);
    _connectChatRealtime(ticketId);
  }

  void _closeTicketThread() {
    _chatChannel?.sink.close();
    _chatChannel = null;
    _chatPollTimer?.cancel();
    _chatPollTimer = null;
    setState(() {
      _openTicketId = null;
      _chatMessages = [];
      _chatLive = false;
    });
  }

  Future<void> _fetchChatMessages(String ticketId) async {
    try {
      final messages = await _api.getGrievanceMessages(ticketId);
      if (mounted && _openTicketId == ticketId) {
        setState(() {
          _chatMessages = messages;
          _chatLoading = false;
        });
        _scrollChatToBottom();
      }
    } catch (e) {
      debugPrint('[NativeRightCenter] fetchChatMessages error: $e');
      if (mounted) setState(() => _chatLoading = false);
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// Connects to the live chat WebSocket for real-time updates. Falls back
  /// to 5s polling if the socket errors, closes, or never opens — mirrors
  /// the NPM SDK's `RightCenter.jsx` chat behavior.
  void _connectChatRealtime(String ticketId) {
    try {
      final uri = _api.grievanceWebSocketUri(ticketId);
      final channel = WebSocketChannel.connect(uri);
      _chatChannel = channel;
      channel.stream.listen(
        (data) {
          if (!mounted || _openTicketId != ticketId) return;
          try {
            final decoded = jsonDecode(data as String);
            if (decoded is Map<String, dynamic>) {
              final message = GrievanceMessage.fromJson(decoded);
              setState(() {
                if (!_chatMessages.any((m) => m.id == message.id)) {
                  _chatMessages = [..._chatMessages, message];
                }
                _chatLive = true;
              });
              _scrollChatToBottom();
            }
          } catch (e) {
            debugPrint('[NativeRightCenter] chat WS message parse error: $e');
          }
        },
        onError: (e) {
          debugPrint('[NativeRightCenter] chat WS error, falling back to polling: $e');
          _startChatPolling(ticketId);
        },
        onDone: () {
          debugPrint('[NativeRightCenter] chat WS closed, falling back to polling');
          if (mounted && _openTicketId == ticketId) _startChatPolling(ticketId);
        },
        cancelOnError: true,
      );
      if (mounted) setState(() => _chatLive = true);
    } catch (e) {
      debugPrint('[NativeRightCenter] chat WS connect failed, falling back to polling: $e');
      _startChatPolling(ticketId);
    }
  }

  void _startChatPolling(String ticketId) {
    if (mounted) setState(() => _chatLive = false);
    _chatPollTimer?.cancel();
    _chatPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _openTicketId != ticketId) {
        _chatPollTimer?.cancel();
        return;
      }
      _fetchChatMessages(ticketId);
    });
  }

  Future<void> _sendChatMessage() async {
    final ticketId = _openTicketId;
    final text = _chatInputController.text.trim();
    if (ticketId == null || text.isEmpty || _chatSending) return;
    setState(() => _chatSending = true);
    try {
      final sent = await _api.sendGrievanceMessage(ticketId, text);
      if (mounted && _openTicketId == ticketId) {
        setState(() {
          if (!_chatMessages.any((m) => m.id == sent.id)) {
            _chatMessages = [..._chatMessages, sent];
          }
          _chatInputController.clear();
        });
        _scrollChatToBottom();
      }
    } catch (e) {
      debugPrint('[NativeRightCenter] sendChatMessage error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _chatSending = false);
    }
  }

  // ─── Tab list ─────────────────────────────────────────────────────────────────

  List<String> get _enabledTabs {
    final tabs = <String>[];
    if (_settings.showConsentsSection) tabs.add('Consent');
    if (_settings.showRightsSection) tabs.add('Rights');
    if (_settings.showNomineesSection) tabs.add('Nominee');
    if (_settings.showGrievanceSection) tabs.add('Grievance');
    if (_settings.showTransparencySection) tabs.add('Transparency');
    if (_settings.showDpoSection) tabs.add('DPO');
    if (tabs.isEmpty) tabs.add('Consent'); // fallback
    return tabs;
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading Rights Center...'),
          ],
        ),
      );
    }

    if (_showOtpGate) {
      return ColoredBox(color: _bgColor, child: _buildOtpGate());
    }

    if (_needsSsoLogin) {
      return ColoredBox(
        color: _bgColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: _secondaryText),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Please log in to view your Rights Center.',
                    style: TextStyle(color: _secondaryText),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_effectiveUserId.isEmpty) {
      // Non-SSO configured, but the OTP screen was dismissed without
      // completing verification: nothing to show without an identity.
      // Mirrors the NPM SDK, which leaves this state blank too.
      return ColoredBox(color: _bgColor);
    }

    final tabs = _enabledTabs;
    if (!tabs.contains(_activeTab)) {
      _activeTab = tabs.first;
    }

    return ColoredBox(
      color: _bgColor,
      child: Column(
        children: [
          // Tab bar
          Container(
            color: _bgColor,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: tabs.map((tab) => _buildTabButton(tab)).toList(),
              ),
            ),
          ),
          Divider(height: 1, color: _borderColor),
          // Content
          Expanded(
            child: _buildTabContent(_activeTab),
          ),
        ],
      ),
    );
  }

  // ─── Non-SSO OTP gate ─────────────────────────────────────────────────────────

  Widget _buildOtpGate() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Verify your phone number',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _primaryText),
                    ),
                  ),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      icon: Icon(Icons.close, color: _secondaryText),
                      tooltip: 'Close',
                      onPressed: () => setState(() => _nonSsoDismissed = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent
                    ? 'Enter the OTP sent to ${_countryCodeController.text}${_phoneController.text}'
                    : 'We need to verify your identity before showing your data rights.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _secondaryText),
              ),
              const SizedBox(height: 20),
              if (!_otpSent) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: TextField(
                        controller: _countryCodeController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_otpError != null) ...[
                  Text(_otpError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                ElevatedButton(
                  onPressed: _otpSending ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(backgroundColor: _btnColor),
                  child: _otpSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Send OTP', style: TextStyle(color: _btnTextColor)),
                ),
              ] else ...[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, letterSpacing: 8),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(),
                    hintText: '••••••',
                  ),
                ),
                const SizedBox(height: 8),
                if (_otpError != null) ...[
                  Text(_otpError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                ElevatedButton(
                  onPressed: _otpVerifying ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(backgroundColor: _btnColor),
                  child: _otpVerifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Verify', style: TextStyle(color: _btnTextColor)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: (_otpResendsUsed >= 3 || _otpCooldownSeconds > 0) ? null : _resendOtp,
                  child: Text(
                    _otpCooldownSeconds > 0
                        ? 'Resend OTP in ${_otpCooldownSeconds}s'
                        : _otpResendsUsed >= 3
                            ? 'No more resends available'
                            : 'Resend OTP',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String label) {
    final isActive = _activeTab == label;
    // Matches truKIT-NPM's .rc-tab-btn.active (solid button-color fill,
    // button-text-color label) / truKIT-react-native's equivalent — not an
    // underline-only style, and the active label uses buttonTextColor, never
    // buttonColor as its own text color.
    return GestureDetector(
      onTap: () => setState(() => _activeTab = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? _btnColor : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isActive ? _btnColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? _btnTextColor : _secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(String tab) {
    switch (tab) {
      case 'Consent':
        return _buildConsentTab();
      case 'Rights':
        return _buildRightsTab();
      case 'Nominee':
        return _buildNomineeTab();
      case 'Grievance':
        return _buildGrievanceTab();
      case 'Transparency':
        return _buildTransparencyTab();
      case 'DPO':
        return _buildDPOTab();
      default:
        return _buildConsentTab();
    }
  }

  // ─── Consent Tab ──────────────────────────────────────────────────────────────

  /// True if [p] has a genuine logged decision (`timestamp > 0`) — used to
  /// filter the non-SSO read-only view down to purposes that were actually
  /// shown/consented to, rather than every purpose in the template.
  bool _hasRealConsentLog(Map<String, dynamic> p) => ((p['timestamp'] as int?) ?? 0) > 0;

  Widget _buildConsentTab() {
    final readOnly = _isNonSsoReadOnly;
    // Non-SSO: only show purposes with a real logged decision, split into
    // "Mandatory Processing" (no consent required) and everything else.
    final visibleConsents = readOnly ? _consents.where(_hasRealConsentLog).toList() : _consents;
    final mandatoryLogged =
        readOnly ? visibleConsents.where((p) => p['is_mandatory'] == true).toList() : <Map<String, dynamic>>[];
    final otherLogged =
        readOnly ? visibleConsents.where((p) => p['is_mandatory'] != true).toList() : visibleConsents;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _settings.consentsSectionTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _primaryText,
                  ),
                ),
              ),
              if (_dirty && !readOnly) ...[
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _saveConsents,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _btnColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text('Save Changes', style: TextStyle(color: _btnTextColor)),
                ),
              ],
            ],
          ),
        ),
        if (_showSaveSuccess)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF059669), size: 18),
                SizedBox(width: 8),
                Text('Consent preferences saved successfully.',
                    style: TextStyle(color: Color(0xFF065F46))),
              ],
            ),
          ),
        if (_consentsLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (visibleConsents.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'You currently have no consent records to display.',
                style: TextStyle(color: _secondaryText),
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...otherLogged.map(_buildConsentCard),
                if (readOnly && mandatoryLogged.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Mandatory Processing (No Consent Required)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _secondaryText),
                  ),
                  const SizedBox(height: 8),
                  ...mandatoryLogged.map(_buildConsentCard),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildConsentCard(Map<String, dynamic> p) {
    final id = p['id'].toString();
    final isMandatory = p['is_mandatory'] == true;
    final isLegitimate = p['isLegitimate'] == true;
    // Legitimate Interest has no accept/decline decision to report — matches truKIT-NPM's
    // RightCenter.jsx: show "Shown:" (was the LI disclosure rendered to the user at all?)
    // instead of "Consented:", and hide the toggle entirely (nothing for it to control).
    final shownToPrincipal = p['shownToPrincipal'] == true;
    final consented = isLegitimate ? shownToPrincipal : p['consented'] == 'accepted';
    final dataElements = (p['dataElements'] as List?)?.cast<dynamic>() ?? [];
    final processingActivities = (p['processingActivities'] as List?)?.cast<dynamic>() ?? [];
    final processingText = processingActivities.isEmpty
        ? 'Not specified'
        : processingActivities
            .map((a) => a is Map ? (a['name'] ?? a['title'] ?? a.toString()) : a.toString())
            .join(', ');
    final readOnly = _isNonSsoReadOnly;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: _bgColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + badges
            Row(
              children: [
                Expanded(
                  child: Text(
                    p['name'] ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _primaryText,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isMandatory)
                  _badge('Necessary', const Color(0xFFFEE2E2), const Color(0xFF991B1B))
                else if (isLegitimate)
                  _badge('Legitimate Interest', const Color(0xFFE0F2FE), const Color(0xFF0369A1))
                else
                  _badge('Optional', const Color(0xFFDCFCE7), const Color(0xFF166534)),
              ],
            ),
            const SizedBox(height: 6),
            // Expiry & processing
            if ((p['expiry_period'] ?? '').toString().isNotEmpty)
              Text(
                'Expiry: ${p['expiry_period']}',
                style: TextStyle(fontSize: 12, color: _secondaryText),
              ),
            const SizedBox(height: 4),
            Text(
              'Processing: $processingText',
              style: TextStyle(fontSize: 12, color: _secondaryText),
            ),
            const SizedBox(height: 8),
            // Status pill (label depends on legitimate-interest, see above) + toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      isLegitimate ? 'Shown: ' : 'Consented: ',
                      style: TextStyle(fontSize: 12, color: _secondaryText),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: consented
                            ? const Color(0xFFD1FAE5)
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        consented ? 'Yes' : 'No',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: consented
                              ? const Color(0xFF065F46)
                              : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
                // Legitimate Interest has no opt-in/opt-out concept — processing happens under
                // that legal basis regardless of user action, so there's nothing to toggle.
                if (!readOnly && !isLegitimate)
                  // Material3's Switch renders a visibly larger thumb when
                  // selected than when unselected (its own spec, not
                  // something thumbColor/trackColor control) — that made
                  // the "same thumb color/size on and off" parity fix below
                  // look inconsistent between states. Material2's Switch
                  // keeps a constant thumb size in both states, matching
                  // truKIT-NPM's plain CSS toggle exactly.
                  Theme(
                    data: ThemeData(
                      useMaterial3: false,
                      brightness: Theme.of(context).brightness,
                    ),
                    child: Switch(
                      value: consented,
                      onChanged: (_) => _toggleConsent(id),
                      // Matches truKIT-NPM's .rc-slider/.rc-slider:before exactly:
                      // the thumb is the same color on and off (the primary
                      // BUTTON text color, not the body text color) — the
                      // track alone carries the on/off signal.
                      activeTrackColor: _btnColor,
                      inactiveTrackColor: _borderColor,
                      activeThumbColor: _btnTextColor,
                      inactiveThumbColor: _btnTextColor,
                    ),
                  ),
              ],
            ),
            // Data elements chips
            if (dataElements.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Data Elements:',
                style: TextStyle(fontSize: 12, color: _secondaryText),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: dataElements.map<Widget>((de) {
                  final name = de is Map ? (de['name'] ?? de.toString()) : de.toString();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _bgColor,
                      border: Border.all(color: _borderColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      name,
                      style: TextStyle(fontSize: 11, color: _primaryText),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  // ─── Rights Tab ───────────────────────────────────────────────────────────────

  Widget _buildRightsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _settings.rightsSectionTitle,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryText),
          ),
          const SizedBox(height: 8),
          Text(
            'You can access, correct, delete, or export your data.',
            style: TextStyle(fontSize: 14, color: _secondaryText),
          ),
          const SizedBox(height: 24),

          // Access Request — button always visible (matches truKIT-NPM/RN reference); the
          // success confirmation is shown transiently inside the dialog below, not by
          // replacing this button, so the user can submit access/deletion requests again.
          ElevatedButton(
            onPressed: () => setState(() {
              _accessConfirmed = false;
              _showAccessModal = true;
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: _btnColor,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: Text('Request to Access My Data', style: TextStyle(color: _btnTextColor)),
          ),

          const SizedBox(height: 16),

          // Delete Request — same "always visible" treatment as above.
          ElevatedButton(
            onPressed: () => setState(() {
              _deleteConfirmed = false;
              _showDeleteModal = true;
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: _btnColor,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: Text('Request to Delete My Data', style: TextStyle(color: _btnTextColor)),
          ),

          // Access confirmation dialog
          if (_showAccessModal)
            _buildConfirmDialog(
              title: 'Confirm Data Access Request',
              message: 'Are you sure you want to request access to your personal data?',
              confirmLabel: 'Confirm',
              onConfirm: _requestAccess,
              onCancel: () => setState(() => _showAccessModal = false),
              confirmed: _accessConfirmed,
              successTitle: 'Request Submitted',
              successMessage: 'Your data access request has been submitted successfully!',
            ),

          // Delete confirmation dialog
          if (_showDeleteModal)
            _buildConfirmDialog(
              title: 'Confirm Data Deletion',
              message:
                  'Are you sure you want to request data deletion? This action cannot be undone.',
              confirmLabel: 'Confirm Deletion',
              onConfirm: _requestDeletion,
              onCancel: () => setState(() => _showDeleteModal = false),
              confirmed: _deleteConfirmed,
              successTitle: 'Request Submitted',
              successMessage: 'Your data deletion request has been submitted successfully!',
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
    bool confirmed = false,
    String successTitle = 'Request Submitted',
    String successMessage = '',
  }) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      color: _bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: _borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: confirmed
              ? [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF059669), size: 20),
                      const SizedBox(width: 8),
                      Text(successTitle,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600, color: _primaryText)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(successMessage, style: TextStyle(fontSize: 14, color: _secondaryText)),
                ]
              : [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, color: _primaryText)),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(fontSize: 14, color: _secondaryText)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Cancel is not destructive — matches truKIT-NPM's rc-btn-secondary
                      // (neutral, themed); the danger-red style belongs only on the actual
                      // delete/confirm action, never on Cancel.
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onCancel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _bgColor,
                            side: BorderSide(color: _borderColor),
                          ),
                          child: Text('Cancel', style: TextStyle(color: _primaryText)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onConfirm,
                          style: ElevatedButton.styleFrom(backgroundColor: _btnColor),
                          child: Text(confirmLabel, style: TextStyle(color: _btnTextColor)),
                        ),
                      ),
                    ],
                  ),
                ],
        ),
      ),
    );
  }

  // ─── Nominee Tab ──────────────────────────────────────────────────────────────

  Widget _buildNomineeTab() {
    final nominee = _nominees.isNotEmpty ? _nominees.first : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _settings.nomineesSectionTitle,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryText),
          ),
          const SizedBox(height: 16),
          // Warning box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Your nominee will be able to exercise all data rights on your behalf.',
              style: TextStyle(fontSize: 14, color: Color(0xFF92400E)),
            ),
          ),
          const SizedBox(height: 16),

          // Existing nominee (view mode)
          if (nominee != null && !_editing)
            Card(
              color: _bgColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Name', nominee.nominee_name),
                    _infoRow('Relationship', nominee.relationship),
                    _infoRow('Email', nominee.nominee_email),
                    _infoRow('Mobile', nominee.nominee_mobile),
                    if (nominee.purpose_of_appointment != null && nominee.purpose_of_appointment!.isNotEmpty)
                      _infoRow('Purpose of Appointment', nominee.purpose_of_appointment!),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => setState(() => _editing = true),
                            style: ElevatedButton.styleFrom(backgroundColor: _btnColor),
                            child: Text('Edit', style: TextStyle(color: _btnTextColor)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _deleteNominee,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                            child: const Text('Delete', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            // Form mode
            Form(
              key: _nomineeFormKey,
              child: Column(
                children: [
                  _textField(
                    label: 'Name *',
                    hint: 'Full name of nominee',
                    key: 'nominee_name',
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  _dropdownField(
                    label: 'Relationship *',
                    key: 'relationship',
                    options: const ['Spouse', 'Parent', 'Child', 'Sibling', 'Other'],
                  ),
                  const SizedBox(height: 16),
                  _textField(
                    label: 'Email *',
                    hint: 'nominee@example.com',
                    key: 'nominee_email',
                    required: true,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _textField(
                    label: 'Mobile Number *',
                    hint: '+1234567890',
                    key: 'nominee_mobile',
                    required: true,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Purpose of Appointment',
                      hintText: 'Explain why you are appointing this nominee',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    initialValue: _nomineeForm['purpose_of_appointment'],
                    onChanged: (v) => _nomineeForm['purpose_of_appointment'] = v,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submitNominee,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _btnColor,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: Text(
                      // Matches truKIT-NPM/truKIT-react-native's label exactly for a
                      // new (non-edit) nominee submission.
                      _editing ? 'Update Nominee' : 'Send Verification Code',
                      style: TextStyle(color: _btnTextColor),
                    ),
                  ),
                  if (_editing) ...[
                    const SizedBox(height: 12),
                    // Cancel (abort edit) is not destructive — matches truKIT-NPM's
                    // rc-btn-secondary; the Delete button on the saved-nominee card
                    // (a separate control) keeps the danger-red style, correctly.
                    ElevatedButton(
                      onPressed: () => setState(() => _editing = false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _bgColor,
                        side: BorderSide(color: _borderColor),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: Text('Cancel', style: TextStyle(color: _primaryText)),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Grievance Tab ────────────────────────────────────────────────────────────

  // Matches truKIT-NPM's RightCenter.jsx status-pill logic (`rc-ticket-status--
  // ${(status || 'open').toLowerCase()}`) — everything that isn't "resolved"
  // reads as "open".
  bool _isTicketResolved(String? status) => (status ?? 'open').toLowerCase() == 'resolved';

  Widget _statusPill(String? status) {
    final resolved = _isTicketResolved(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: resolved ? _successBg : _infoBg,
        borderRadius: BorderRadius.circular(20),
        border: resolved ? null : Border.all(color: _infoBorder),
      ),
      child: Text(
        (status ?? 'Open').toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: resolved ? _successText : _btnColor,
        ),
      ),
    );
  }

  Widget _buildGrievanceThread() {
    final ticketId = _openTicketId!;
    final ticket = _tickets.firstWhere(
      (t) => (t.ticket_id ?? t.id) == ticketId,
      orElse: () => GrievanceTicket(subject: 'Ticket', category: '', description: ''),
    );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: _borderColor)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: _primaryText),
                onPressed: _closeTicketThread,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ticket.subject,
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600, color: _primaryText)),
                    Text(
                      _chatLive ? 'Live' : 'Updates every 5s',
                      style: TextStyle(
                        fontSize: 11,
                        color: _chatLive ? const Color(0xFF059669) : _secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              // Matches truKIT-NPM's RightCenter.jsx chat header status pill —
              // previously missing entirely from this drawer.
              _statusPill(ticket.status),
            ],
          ),
        ),
        Expanded(
          child: _chatLoading
              ? const Center(child: CircularProgressIndicator())
              : _chatMessages.isEmpty
                  ? Center(
                      child: Text('No messages yet. Say hello!',
                          style: TextStyle(color: _secondaryText)),
                    )
                  : ListView.builder(
                      controller: _chatScrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _chatMessages.length,
                      itemBuilder: (ctx, i) => _buildChatBubble(_chatMessages[i]),
                    ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: _borderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatInputController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Type a message…',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (_) => _sendChatMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _chatSending
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.send, color: _btnColor),
                onPressed: _chatSending ? null : _sendChatMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatBubble(GrievanceMessage message) {
    final isUser = message.sender == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        // Matches truKIT-NPM's RightCenter.css: the admin/agent bubble is
        // themed (background/border/text), not a hardcoded light gray —
        // which looks jarring against a dark Rights Center theme.
        decoration: BoxDecoration(
          color: isUser ? _btnColor : _bgColor,
          border: isUser ? null : Border.all(color: _borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.message,
          style: TextStyle(color: isUser ? _btnTextColor : _primaryText),
        ),
      ),
    );
  }

  Widget _buildGrievanceTab() {
    if (_openTicketId != null) {
      return _buildGrievanceThread();
    }

    // External mode
    if (_settings.grievanceMode == 'external' &&
        _settings.grievanceExternalUrl.isNotEmpty) {
      return Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open Grievance Portal'),
          onPressed: () async {
            final uri = Uri.tryParse(_settings.grievanceExternalUrl);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Grievance Tickets',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryText)),
                    const SizedBox(height: 4),
                    Text('Submit privacy concerns or view your existing tickets',
                        style: TextStyle(fontSize: 13, color: _secondaryText)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => setState(() => _showGrievanceForm = !_showGrievanceForm),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _btnColor,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                child: Text('Create New Ticket', style: TextStyle(color: _btnTextColor, fontSize: 13)),
              ),
            ],
          ),
          if (_showGrievanceForm) ...[
            const SizedBox(height: 16),
            Form(
              key: _grievanceFormKey,
              child: Column(
                children: [
                  _textField(
                    label: 'Subject *',
                    hint: 'Brief description of your concern',
                    key: 'subject',
                    required: true,
                    formMap: _grievanceForm,
                  ),
                  const SizedBox(height: 16),
                  _dropdownField(
                    label: 'Category *',
                    key: 'category',
                    options: const ['Privacy Concern', 'Data Access', 'Other'],
                    formMap: _grievanceForm,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Description *',
                      hintText: 'Detailed description of your concern or request',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    initialValue: _grievanceForm['description'],
                    onChanged: (v) => _grievanceForm['description'] = v,
                    validator: (v) => (v?.isEmpty ?? true) ? 'Description is required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submitGrievance,
                          style: ElevatedButton.styleFrom(backgroundColor: _btnColor),
                          child: Text('Submit Ticket', style: TextStyle(color: _btnTextColor)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _showGrievanceForm = false),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Your Tickets',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _primaryText)),
          const SizedBox(height: 12),
          if (_tickets.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('No tickets found. Create your first grievance ticket above.',
                    style: TextStyle(color: _secondaryText)),
              ),
            )
          else
            ..._tickets.map((ticket) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: _bgColor,
                  child: InkWell(
                    onTap: () => _openTicket(ticket),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(ticket.subject,
                                    style: TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w600, color: _primaryText)),
                              ),
                              _statusPill(ticket.status),
                            ],
                          ),
                          if (ticket.ticket_id != null) ...[
                            const SizedBox(height: 4),
                            Text('Ticket #${ticket.ticket_id}',
                                style: TextStyle(fontSize: 11, color: _secondaryText)),
                          ],
                          const SizedBox(height: 6),
                          Text(ticket.category, style: TextStyle(fontSize: 12, color: _secondaryText)),
                          const SizedBox(height: 4),
                          Text(ticket.description,
                              style: TextStyle(fontSize: 14, color: _secondaryText, height: 1.5)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 14, color: _secondaryText),
                              const SizedBox(width: 4),
                              Text('View conversation',
                                  style: TextStyle(fontSize: 12, color: _secondaryText)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  // ─── Transparency Tab ─────────────────────────────────────────────────────────

  Widget _buildTransparencyTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Transparency',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryText)),
          const SizedBox(height: 8),
          Text(
            _settings.transparencyDescription.isNotEmpty
                ? _settings.transparencyDescription
                : 'We collect your data to provide better services and comply with regulations. '
                    'Your data is stored securely and used only for the purposes you\'ve consented to.',
            style: TextStyle(fontSize: 14, color: _secondaryText, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ─── DPO Tab ──────────────────────────────────────────────────────────────────

  Widget _buildDPOTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DPO Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryText)),
          const SizedBox(height: 16),
          if (_dpoInfo == null)
            Text('No DPO information available.', style: TextStyle(color: _secondaryText))
          else
            Card(
              color: _bgColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow('Full Name', _dpoInfo!.full_name ?? 'N/A'),
                    _infoRow('Email', _dpoInfo!.email ?? 'N/A'),
                    _infoRow('Appointment Date', _dpoInfo!.appointment_date ?? 'N/A'),
                    if (_settings.dpoQualificationsEnabled)
                      _infoRow('Qualifications', _dpoInfo!.qualifications ?? 'N/A'),
                    if (_settings.dpoResponsibilitiesEnabled)
                      _infoRow('Responsibilities', _dpoInfo!.responsibilities ?? 'N/A'),
                    if (_settings.dpoWorkingHoursEnabled)
                      _infoRow('Working Hours', _dpoInfo!.working_hours ?? 'N/A'),
                    if (_settings.dpoResponseTimeEnabled)
                      _infoRow('Response Time', _dpoInfo!.response_time ?? 'N/A'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Shared helpers ───────────────────────────────────────────────────────────

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: _secondaryText)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _primaryText)),
        ],
      ),
    );
  }

  Widget _textField({
    required String label,
    required String hint,
    required String key,
    bool required = false,
    TextInputType? keyboardType,
    Map<String, String>? formMap,
  }) {
    final map = formMap ?? _nomineeForm;
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      initialValue: map[key],
      onChanged: (v) => map[key] = v,
      validator: required ? (v) => (v?.isEmpty ?? true) ? '${label.replaceAll(' *', '')} is required' : null : null,
    );
  }

  Widget _dropdownField({
    required String label,
    required String key,
    required List<String> options,
    Map<String, String>? formMap,
  }) {
    final map = formMap ?? _nomineeForm;
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      value: (map[key]?.isEmpty ?? true) ? null : map[key],
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: (v) => map[key] = v ?? '',
      validator: (v) => (v?.isEmpty ?? true) ? '${label.replaceAll(' *', '')} is required' : null,
    );
  }
}
