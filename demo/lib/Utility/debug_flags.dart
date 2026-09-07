/// Master switch for in-app debug tooling (the fake-account switcher and its
/// UI entry points).
///
/// Off by default in every build — including debug builds — so the debug
/// features never show up unless explicitly enabled. Turn it on for a session
/// with a dart-define:
///
///   flutter run --dart-define=SHOW_DEBUG_TOOLS=true
const bool kShowDebugTools = bool.fromEnvironment('SHOW_DEBUG_TOOLS');
