class GeminiConfig {
  GeminiConfig._();

  // Centralized Gemini API key for voice-over integrations.
  static const String apiKey =
      '';

  static bool get isConfigured => apiKey.trim().isNotEmpty;
}