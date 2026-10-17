import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class KitchenAudioService {
  static bool isMuted = false;

  /// Plays a cheerful 2-tone restaurant service chime (New KOT received)
  static Future<void> playNewOrderChime() async {
    if (isMuted) return;

    try {
      // 1. Play OS native alert chime
      await SystemSound.play(SystemSoundType.alert);
      // 2. Heavy haptic vibration on mobile devices
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('Audio chime error: $e');
    }
  }

  /// Plays an urgent dual-beep alert for delayed orders (>15 mins)
  static Future<void> playDelayedOrderAlert() async {
    if (isMuted) return;

    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 200));
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      debugPrint('Delayed alert error: $e');
    }
  }

  /// Synthesizes a pleasant bell chime PCM WAV in-memory bytes
  /// (44.1kHz, 16-bit mono sine wave with exponential decay)
  static Uint8List generateChimeWav({
    double frequency1 = 659.25, // E5
    double frequency2 = 880.00, // A5
    double durationSeconds = 0.8,
  }) {
    const int sampleRate = 44100;
    final int totalSamples = (sampleRate * durationSeconds).toInt();
    final int dataSize = totalSamples * 2; // 16-bit = 2 bytes per sample

    final bytes = ByteData(44 + dataSize);

    // RIFF chunk
    bytes.setUint8(0, 0x52); // 'R'
    bytes.setUint8(1, 0x49); // 'I'
    bytes.setUint8(2, 0x46); // 'F'
    bytes.setUint8(3, 0x46); // 'F'
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    bytes.setUint8(8, 0x57);  // 'W'
    bytes.setUint8(9, 0x41);  // 'A'
    bytes.setUint8(10, 0x56); // 'V'
    bytes.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    bytes.setUint8(12, 0x66); // 'f'
    bytes.setUint8(13, 0x6D); // 'm'
    bytes.setUint8(14, 0x74); // 't'
    bytes.setUint8(15, 0x20); // ' '
    bytes.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    bytes.setUint16(20, 1, Endian.little);  // AudioFormat (1 = PCM)
    bytes.setUint16(22, 1, Endian.little);  // NumChannels (1 = Mono)
    bytes.setUint32(24, sampleRate, Endian.little); // SampleRate
    bytes.setUint32(28, sampleRate * 2, Endian.little); // ByteRate (SampleRate * NumChannels * BitsPerSample/8)
    bytes.setUint16(32, 2, Endian.little);  // BlockAlign (NumChannels * BitsPerSample/8)
    bytes.setUint16(34, 16, Endian.little); // BitsPerSample (16 bits)

    // data subchunk
    bytes.setUint8(36, 0x64); // 'd'
    bytes.setUint8(37, 0x61); // 'a'
    bytes.setUint8(38, 0x74); // 't'
    bytes.setUint8(39, 0x61); // 'a'
    bytes.setUint32(40, dataSize, Endian.little);

    // Generate bell waveform
    final halfSamples = totalSamples ~/ 2;
    for (int i = 0; i < totalSamples; i++) {
      final double t = i / sampleRate;
      final double decay = exp(-4.5 * t);
      // First half primarily freq1, second half blends freq2
      final double freq = i < halfSamples ? frequency1 : frequency2;
      final double sample = sin(2 * pi * freq * t) * decay * 0.7;
      final int sampleInt = (sample * 32767).toInt().clamp(-32768, 32767);
      bytes.setInt16(44 + i * 2, sampleInt, Endian.little);
    }

    return bytes.buffer.asUint8List();
  }
}
