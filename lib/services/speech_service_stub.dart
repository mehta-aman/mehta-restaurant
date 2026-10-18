class SpeechPlatformDelegate {
  static bool get isSupported => false;

  static bool startListening({
    required Function(String text, bool isFinal) onResult,
    required Function() onEnd,
    required Function(String error) onError,
  }) {
    return false;
  }

  static void stopListening() {}

  static bool speak(String text) {
    return false;
  }

  static void stopSpeaking() {}
}
