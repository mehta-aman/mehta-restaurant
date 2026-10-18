import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

@JS('mehtaVoice')
external JSObject? get _mehtaVoice;

@JS('mehtaVoice.isSupported')
external bool _isSupported();

@JS('mehtaVoice.startListening')
external bool _startListening(String lang);

@JS('mehtaVoice.stopListening')
external void _stopListening();

@JS('mehtaVoice.speak')
external bool _speak(String text);

@JS('mehtaVoice.stopSpeaking')
external void _stopSpeaking();

class SpeechPlatformDelegate {
  static web.EventListener? _resultListener;
  static web.EventListener? _errorListener;
  static web.EventListener? _endListener;

  static bool get isSupported {
    try {
      if (_mehtaVoice != null) {
        return _isSupported();
      }
    } catch (_) {}
    return false;
  }

  static bool startListening({
    required Function(String text, bool isFinal) onResult,
    required Function() onEnd,
    required Function(String error) onError,
  }) {
    try {
      if (_mehtaVoice == null) return false;

      _cleanListeners();

      _resultListener = ((web.Event event) {
        if (event.isA<web.CustomEvent>()) {
          final customEvent = event as web.CustomEvent;
          final detail = customEvent.detail;
          if (detail != null && detail.isA<JSObject>()) {
            final obj = detail as JSObject;
            final textObj = obj.getProperty<JSString?>('text'.toJS);
            final isFinalObj = obj.getProperty<JSBoolean?>('isFinal'.toJS);
            final text = textObj?.toDart ?? '';
            final isFinal = isFinalObj?.toDart ?? false;
            onResult(text, isFinal);
          }
        }
      }).toJS;

      _errorListener = ((web.Event event) {
        if (event.isA<web.CustomEvent>()) {
          final customEvent = event as web.CustomEvent;
          final detail = customEvent.detail;
          onError(detail?.toString() ?? 'Speech recognition error');
        } else {
          onError('Speech recognition error');
        }
      }).toJS;

      _endListener = ((web.Event event) {
        onEnd();
      }).toJS;

      web.window.addEventListener('mehta_voice_result', _resultListener);
      web.window.addEventListener('mehta_voice_error', _errorListener);
      web.window.addEventListener('mehta_voice_end', _endListener);

      return _startListening('en-IN');
    } catch (e) {
      onError(e.toString());
      return false;
    }
  }

  static void stopListening() {
    try {
      if (_mehtaVoice != null) {
        _stopListening();
      }
    } catch (_) {}
    _cleanListeners();
  }

  static bool speak(String text) {
    try {
      if (_mehtaVoice != null) {
        return _speak(text);
      }
    } catch (_) {}
    return false;
  }

  static void stopSpeaking() {
    try {
      if (_mehtaVoice != null) {
        _stopSpeaking();
      }
    } catch (_) {}
  }

  static void _cleanListeners() {
    if (_resultListener != null) {
      web.window.removeEventListener('mehta_voice_result', _resultListener);
      _resultListener = null;
    }
    if (_errorListener != null) {
      web.window.removeEventListener('mehta_voice_error', _errorListener);
      _errorListener = null;
    }
    if (_endListener != null) {
      web.window.removeEventListener('mehta_voice_end', _endListener);
      _endListener = null;
    }
  }
}
