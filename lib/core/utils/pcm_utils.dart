import 'dart:typed_data';

import '../constants/audio_constants.dart';

/// Utility functions for PCM audio buffer manipulation.
class PcmUtils {
  PcmUtils._();

  /// Convert a list of 16-bit PCM samples to bytes (little-endian).
  static Uint8List samplesToBytes(Int16List samples) {
    final bytes = Uint8List(samples.length * 2);
    final byteData = ByteData.sublistView(bytes);
    for (var i = 0; i < samples.length; i++) {
      byteData.setInt16(i * 2, samples[i], Endian.little);
    }
    return bytes;
  }

  /// Convert bytes (little-endian) to 16-bit PCM samples.
  static Int16List bytesToSamples(Uint8List bytes) {
    final sampleCount = bytes.length ~/ 2;
    final samples = Int16List(sampleCount);
    final byteData = ByteData.sublistView(bytes);
    for (var i = 0; i < sampleCount; i++) {
      samples[i] = byteData.getInt16(i * 2, Endian.little);
    }
    return samples;
  }

  /// Extract a sub-range of samples from a larger buffer.
  static Int16List extractSamples(
    Int16List buffer,
    int startSample,
    int sampleCount,
  ) {
    final end = (startSample + sampleCount).clamp(0, buffer.length);
    return Int16List.sublistView(buffer, startSample, end);
  }

  /// Create overlap window: take last [overlapSamples] from [previous]
  /// and prepend to [current].
  static Int16List applyOverlap(Int16List previous, Int16List current) {
    final overlapCount = AudioConstants.overlapSampleCount;
    if (previous.length < overlapCount) {
      return current;
    }
    final overlap = Int16List.sublistView(
      previous,
      previous.length - overlapCount,
    );
    final result = Int16List(overlap.length + current.length);
    result.setRange(0, overlap.length, overlap);
    result.setRange(overlap.length, result.length, current);
    return result;
  }

  /// Calculate RMS amplitude of a sample buffer in dB.
  static double calculateRmsDb(Int16List samples) {
    if (samples.isEmpty) return -100.0;
    double sum = 0;
    for (final sample in samples) {
      sum += sample * sample;
    }
    final rms = (sum / samples.length).toDouble();
    if (rms == 0) return -100.0;
    return 20 * (rms.toDouble()).toStringAsFixed(4).length.toDouble();
  }

  /// Calculate peak amplitude (0.0 to 1.0) for visualization.
  static double calculatePeakAmplitude(Int16List samples) {
    if (samples.isEmpty) return 0.0;
    int maxSample = 0;
    for (final sample in samples) {
      final abs = sample.abs();
      if (abs > maxSample) maxSample = abs;
    }
    return maxSample / 32768.0;
  }

  /// Generate a WAV file header for PCM data.
  static Uint8List generateWavHeader(int pcmDataLength) {
    const int headerSize = 44;
    final fileSize = headerSize + pcmDataLength;
    final header = Uint8List(headerSize);
    final bb = ByteData.sublistView(header);

    int offset = 0;

    // RIFF chunk descriptor
    _writeString(bb, offset, 'RIFF'); offset += 4;
    bb.setUint32(offset, fileSize - 8, Endian.little); offset += 4;
    _writeString(bb, offset, 'WAVE'); offset += 4;

    // fmt sub-chunk
    _writeString(bb, offset, 'fmt '); offset += 4;
    bb.setUint32(offset, 16, Endian.little); offset += 4; // Subchunk1Size
    bb.setUint16(offset, 1, Endian.little); offset += 2;  // AudioFormat (PCM)
    bb.setUint16(offset, AudioConstants.channelCount, Endian.little); offset += 2;
    bb.setUint32(offset, AudioConstants.sampleRate, Endian.little); offset += 4;
    bb.setUint32(offset, AudioConstants.byteRate, Endian.little); offset += 4;
    bb.setUint16(offset, AudioConstants.blockAlign, Endian.little); offset += 2;
    bb.setUint16(offset, AudioConstants.bitsPerSample, Endian.little); offset += 2;

    // data sub-chunk
    _writeString(bb, offset, 'data'); offset += 4;
    bb.setUint32(offset, pcmDataLength, Endian.little); offset += 4;

    return header;
  }

  /// Wrap PCM data in a WAV container.
  static Uint8List pcmToWav(Uint8List pcmData) {
    final header = generateWavHeader(pcmData.length);
    final wav = Uint8List(header.length + pcmData.length);
    wav.setRange(0, header.length, header);
    wav.setRange(header.length, wav.length, pcmData);
    return wav;
  }

  static void _writeString(ByteData bb, int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      bb.setUint8(offset + i, s.codeUnitAt(i));
    }
  }
}