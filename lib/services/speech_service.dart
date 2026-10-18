import 'package:flutter/foundation.dart';
import 'speech_service_stub.dart'
    if (dart.library.js_interop) 'speech_service_web.dart';

class SpeechService {
  static bool get isSupported => SpeechPlatformDelegate.isSupported;
  static bool isSpeakingEnabled = true;

  static bool startListening({
    required Function(String text, bool isFinal) onResult,
    required Function() onEnd,
    required Function(String error) onError,
  }) {
    debugPrint('[SpeechService] startListening invoked');
    return SpeechPlatformDelegate.startListening(
      onResult: onResult,
      onEnd: onEnd,
      onError: onError,
    );
  }

  static void stopListening() {
    debugPrint('[SpeechService] stopListening invoked');
    SpeechPlatformDelegate.stopListening();
  }

  static bool speak(String text) {
    if (!isSpeakingEnabled) return false;
    debugPrint('[SpeechService] speak invoked: "$text"');
    return SpeechPlatformDelegate.speak(text);
  }

  static void stopSpeaking() {
    SpeechPlatformDelegate.stopSpeaking();
  }
}
