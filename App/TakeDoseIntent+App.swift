import AppIntents

// WidgetKit runs an intent with this conformance in the app process, in the background (D048).
// The protocol is deprecated for `supportedModes`, and the new key does not say where the intent runs.
// The widget extension cannot use the protocol, so only the app target has this file.
@available(*, deprecated)
extension TakeDoseIntent: ForegroundContinuableIntent {}
