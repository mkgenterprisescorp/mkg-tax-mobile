/// Client-side mirror of Laravel `TESSA_VOICE_ENABLED` (default false).
///
/// Keep voice UI and preference writes disabled until this flag is flipped in a
/// reviewed change that also confirms Laravel `TESSA_VOICE_ENABLED=true` and
/// per-locale QA. Do not enable from device settings or silent detection.
class TessaVoiceFlags {
  TessaVoiceFlags._();

  /// Reviewed Phase 1 default: voice off.
  static const bool voiceEnabled = false;
}
