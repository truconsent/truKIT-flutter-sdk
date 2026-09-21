import 'package:flutter/material.dart';

/// H-Case warning popup widget.
///
/// Shown when a user tries to decline any mandatory consent purpose.
/// Supports two strategies: 'soft_first' (Go Back + Proceed Anyway)
/// and 'hard_immediate' (OK only).
class HCaseWarningWidget extends StatelessWidget {
  /// Strategy: 'soft_first' or 'hard_immediate'
  final String strategy;

  /// Warning message to display
  final String message;

  /// Text for the proceed button
  final String? proceedText;

  /// Text for the back button (only used in soft_first)
  final String? backText;

  /// Called when user proceeds anyway
  final VoidCallback onProceed;

  /// Called when user goes back (only in soft_first)
  final VoidCallback? onBack;

  /// Primary color for buttons
  final Color? primaryColor;

  /// h_case_proceed_button_color from the notice's Global Settings. When
  /// unset, falls back to primaryColor for both strategies, matching
  /// truKIT-NPM's HCaseWarningPopup.jsx (which never hardcodes red here).
  final Color? proceedColor;

  /// h_case_back_button_color from the notice's Global Settings. When unset,
  /// keeps the outlined style below.
  final Color? backColor;

  const HCaseWarningWidget({
    super.key,
    required this.strategy,
    required this.message,
    required this.onProceed,
    this.onBack,
    this.proceedText,
    this.backText,
    this.primaryColor,
    this.proceedColor,
    this.backColor,
  });

  @override
  Widget build(BuildContext context) {
    final isSoft = strategy == 'soft_first';
    final resolvedProceedText = proceedText ?? (isSoft ? 'Proceed Anyway' : 'OK');
    final resolvedBackText = backText ?? 'Go Back';
    final btnColor = primaryColor ?? const Color(0xFF3b82f6);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Warning icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF59E0B), width: 2),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFD97706),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          // Title
          const Text(
            'Consent Required',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          // Message
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4B5563),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          // Buttons
          if (isSoft) ...[
            Row(
              children: [
                Expanded(
                  child: backColor != null
                      ? ElevatedButton(
                          onPressed: onBack,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: backColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            resolvedBackText,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : OutlinedButton(
                          onPressed: onBack,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: btnColor, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            resolvedBackText,
                            style: TextStyle(
                              color: btnColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onProceed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: proceedColor ?? btnColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      resolvedProceedText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onProceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: proceedColor ?? btnColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  resolvedProceedText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
