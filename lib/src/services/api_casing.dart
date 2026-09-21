/// The SDK's models (Banner, BannerSettings, Purpose, ...) are parsed with
/// snake_case JSON keys, matching the admin-preview backend's raw
/// NoticeGlobalSettings-shaped dict. But the actual production SDK API
/// (trukit-dev.truconsent.io — this package's own `defaultApiBaseUrl`)
/// returns PURE camelCase (confirmed against a live response: `primaryColor`,
/// `rejectAllColor`, `bannerId`, `isMandatory`, `expiryPeriod`, etc. — no
/// snake_case siblings at all). Without this normalization, every field read
/// as `json['primary_color']`/`json['banner_id']`/etc. is silently absent
/// against that API, which is why colors/fonts/H-Case overrides never
/// appeared even though the SDK's own logic for consuming them was otherwise
/// correct.
///
/// Adds a snake_case alias for every camelCase key an object has (and vice
/// versa), non-destructively (existing keys are never overwritten), one
/// level deep. Applied once at the API response boundary (banner_service.dart)
/// so every existing snake_case-based `fromJson` read keeps working
/// regardless of which casing convention the backend serving a given
/// deployment actually uses — mirrors truKIT-NPM's
/// `normalizeBannerSettings()`, generalized so new fields don't need a
/// hand-maintained mapping.
library;

String _camelToSnake(String key) {
  final buffer = StringBuffer();
  for (final rune in key.runes) {
    final ch = String.fromCharCode(rune);
    if (ch.toUpperCase() == ch && ch.toLowerCase() != ch) {
      buffer.write('_${ch.toLowerCase()}');
    } else {
      buffer.write(ch);
    }
  }
  return buffer.toString();
}

String _snakeToCamel(String key) {
  final parts = key.split('_');
  if (parts.length <= 1) return key;
  final buffer = StringBuffer(parts.first);
  for (final part in parts.skip(1)) {
    if (part.isEmpty) continue;
    buffer.write(part[0].toUpperCase());
    buffer.write(part.substring(1));
  }
  return buffer.toString();
}

/// Returns a shallow copy of [obj] with a snake_case alias added for every
/// camelCase key, and a camelCase alias added for every snake_case key.
/// Never overwrites a key that's already present.
Map<String, dynamic> withCasingAliases(Map<String, dynamic>? obj) {
  if (obj == null) return {};
  final result = Map<String, dynamic>.from(obj);
  for (final key in obj.keys.toList()) {
    final snake = _camelToSnake(key);
    if (snake != key && !result.containsKey(snake)) {
      result[snake] = obj[key];
    }
    final camel = _snakeToCamel(key);
    if (camel != key && !result.containsKey(camel)) {
      result[camel] = obj[key];
    }
  }
  return result;
}

/// Applies [withCasingAliases] to every item of [list] (items that aren't
/// maps are left untouched).
List<dynamic> withCasingAliasesList(List<dynamic>? list) {
  if (list == null) return [];
  return list
      .map((item) => item is Map<String, dynamic> ? withCasingAliases(item) : item)
      .toList();
}
