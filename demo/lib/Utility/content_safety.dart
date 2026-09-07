abstract final class ContentSafety {
  ContentSafety._();

  static final List<RegExp> _blockedPatterns = [
    RegExp(r'\b(?:kill|hurt)\s+(?:yourself|urself)\b', caseSensitive: false),
    RegExp(r'\b(?:nudes?|porn(?:ography)?)\b', caseSensitive: false),
    RegExp(
      r'\b(?:doxx?|home address)\s+(?:them|him|her|this person)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:racial|homophobic|transphobic)\s+slur\b',
      caseSensitive: false,
    ),
  ];

  static void validatePost({required String title, required String body}) {
    final combined = '$title\n$body';
    if (_blockedPatterns.any((pattern) => pattern.hasMatch(combined))) {
      throw const UnsafeContentException();
    }
  }
}

class UnsafeContentException implements Exception {
  const UnsafeContentException();

  @override
  String toString() =>
      'This post may violate Quilt’s community safety rules. Revise it before publishing.';
}
