import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Resilient cross-platform URL launcher utility with multi-tier fallbacks.
class UrlLauncherUtils {
  UrlLauncherUtils._();

  /// Attempts to launch [urlString] via external browser app, falling back to
  /// platform default, and finally in-app browser view.
  static Future<bool> openUrl(String urlString) async {
    final trimmed = urlString.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;

    // 1. Try launching in external application (e.g. Chrome, Firefox, Safari)
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } catch (e) {
      debugPrint('LaunchMode.externalApplication failed for $trimmed: $e');
    }

    // 2. Try default platform launch mode
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (launched) return true;
    } catch (e) {
      debugPrint('LaunchMode.platformDefault failed for $trimmed: $e');
    }

    // 3. Fallback to in-app browser view
    try {
      return await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (e) {
      debugPrint('LaunchMode.inAppBrowserView failed for $trimmed: $e');
      return false;
    }
  }
}
