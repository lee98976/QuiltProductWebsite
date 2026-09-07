class ParentConnectionLink {
  const ParentConnectionLink._();

  static const String scheme = 'quilt';
  static const String host = 'connect';
  static final RegExp _familyCodePattern = RegExp(r'^[A-Z2-9]{6}$');
  static final RegExp _requestIdPattern = RegExp(r'^[^\s/]{3,300}$');

  static Uri create(String familyCode) {
    final code = normalizeFamilyCode(familyCode);
    if (!_familyCodePattern.hasMatch(code)) {
      throw ArgumentError.value(
        familyCode,
        'familyCode',
        'Invalid family code',
      );
    }

    return Uri(
      scheme: scheme,
      host: host,
      queryParameters: const {'v': '1'},
    ).replace(queryParameters: {'v': '1', 'code': code});
  }

  static Uri createParentRequest(String requestId) {
    final id = requestId.trim();
    if (!_requestIdPattern.hasMatch(id)) {
      throw ArgumentError.value(
        requestId,
        'requestId',
        'Invalid parent request id',
      );
    }

    return Uri(
      scheme: scheme,
      host: host,
      queryParameters: {'v': '1', 'type': 'parent_request', 'request': id},
    );
  }

  static String normalizeFamilyCode(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  /// Returns the family code from a Quilt connection link.
  ///
  /// Plain six-character codes are also accepted so older printed QR codes
  /// continue to work inside the app's scanner.
  static String? familyCodeFrom(String value) {
    final normalizedValue = value.trim();
    final plainCode = normalizeFamilyCode(normalizedValue);
    if (_familyCodePattern.hasMatch(plainCode)) return plainCode;

    final uri = Uri.tryParse(normalizedValue);
    if (uri == null ||
        uri.scheme.toLowerCase() != scheme ||
        uri.host.toLowerCase() != host) {
      return null;
    }

    final code = normalizeFamilyCode(uri.queryParameters['code'] ?? '');
    return _familyCodePattern.hasMatch(code) ? code : null;
  }

  /// Returns the pending parent request id from a guardian confirmation QR.
  static String? parentRequestIdFrom(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme.toLowerCase() != scheme ||
        uri.host.toLowerCase() != host ||
        uri.queryParameters['type'] != 'parent_request') {
      return null;
    }

    final requestId = uri.queryParameters['request']?.trim() ?? '';
    return _requestIdPattern.hasMatch(requestId) ? requestId : null;
  }
}
