import 'dart:io';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../../../../../core/constants/audio_constants.dart';
import '../../../../../core/utils/pcm_utils.dart';

/// Local data source for audio file I/O operations.
///
/// Handles reading and writing of PCM/WAV audio files on the local
/// file system. This class isolates file system operations from the
/// repository layer, making it easier to test and swap implementations.
///
/// All file paths should be absolute paths obtained from
/// [AudioFileNaming] utility methods.
@injectable
class AudioLocalDataSource {
  final Logger _logger;

  /// Creates the audio local data source.
  AudioLocalDataSource({required Logger logger}) : _logger = logger;

  /// Read audio data from a file.
  ///
  /// [filePath] - Absolute path to the audio file.
  ///
  /// Returns the raw file bytes.
  /// Throws [FileSystemException] if the file doesn't exist or can't be read.
  Future<Uint8List> readAudioFile(String filePath) async {
    try {
      _logger.d('AudioLocalDataSource: Reading file $filePath');
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException('Audio file not found', filePath);
      }
      return await file.readAsBytes();
    } catch (e, stackTrace) {
      _logger.e(
        'AudioLocalDataSource: Failed to read audio file: $filePath',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Read only the PCM payload from a WAV file (strip header).
  ///
  /// [filePath] - Absolute path to the WAV file.
  ///
  /// Returns just the PCM data bytes without the 44-byte WAV header.
  /// If the file is already raw PCM (no RIFF header), returns all data.
  Future<Uint8List> readPcmFromWavFile(String filePath) async {
    try {
      _logger.d('AudioLocalDataSource: Reading PCM from WAV file $filePath');
      final data = await readAudioFile(filePath);

      // Check if this is a WAV file
      if (data.length < 44) return data;

      final isWav = data[0] == 0x52 && // R
          data[1] == 0x49 && // I
          data[2] == 0x46 && // F
          data[3] == 0x46; // F

      if (isWav) {
        // Find 'data' chunk offset
        final pcmStart = _findDataChunkOffset(data);
        _logger.d('AudioLocalDataSource: Stripped WAV header, PCM starts at byte $pcmStart');
        return Uint8List.sublistView(data, pcmStart);
      }

      return data;
    } catch (e, stackTrace) {
      _logger.e(
        'AudioLocalDataSource: Failed to read PCM from WAV: $filePath',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Write PCM audio data to a file.
  ///
  /// [filePath] - Absolute path where the file should be written.
  /// [pcmData] - Raw PCM16 audio data.
  ///
  /// Creates parent directories if they don't exist.
  Future<void> writePcmFile(String filePath, Uint8List pcmData) async {
    try {
      _logger.d('AudioLocalDataSource: Writing PCM file $filePath (${pcmData.length} bytes)');
      final file = File(filePath);
      final dir = Directory(p.dirname(filePath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await file.writeAsBytes(pcmData);
    } catch (e, stackTrace) {
      _logger.e(
        'AudioLocalDataSource: Failed to write PCM file: $filePath',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Write PCM audio data wrapped in a WAV container.
  ///
  /// [filePath] - Absolute path where the WAV file should be written.
  /// [pcmData] - Raw PCM16 audio data.
  ///
  /// Uses [PcmUtils.pcmToWav] to generate the proper WAV header.
  /// Creates parent directories if they don't exist.
  Future<void> writeWavFile(String filePath, Uint8List pcmData) async {
    try {
      _logger.d('AudioLocalDataSource: Writing WAV file $filePath (${pcmData.length} bytes PCM)');
      final wavData = PcmUtils.pcmToWav(pcmData);
      final file = File(filePath);
      final dir = Directory(p.dirname(filePath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await file.writeAsBytes(wavData);
      _logger.d('AudioLocalDataSource: WAV file written (${wavData.length} bytes total)');
    } catch (e, stackTrace) {
      _logger.e(
        'AudioLocalDataSource: Failed to write WAV file: $filePath',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete an audio file.
  ///
  /// [filePath] - Absolute path to the file to delete.
  ///
  /// Returns true if the file was deleted, false if it didn't exist.
  Future<bool> deleteAudioFile(String filePath) async {
    try {
      _logger.d('AudioLocalDataSource: Deleting file $filePath');
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      _logger.e(
        'AudioLocalDataSource: Failed to delete file: $filePath',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Check if an audio file exists.
  ///
  /// [filePath] - Absolute path to the file.
  ///
  /// Returns true if the file exists.
  Future<bool> fileExists(String filePath) async {
    return File(filePath).exists();
  }

  /// Get the size of an audio file in bytes.
  ///
  /// [filePath] - Absolute path to the file.
  ///
  /// Returns the file size in bytes, or 0 if the file doesn't exist.
  Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      _logger.w('AudioLocalDataSource: Could not get file size for $filePath');
      return 0;
    }
  }

  /// Get the duration of an audio file in milliseconds.
  ///
  /// Calculates duration based on file size and the configured
  /// sample rate, channel count, and bits per sample.
  ///
  /// [filePath] - Absolute path to the audio file (PCM or WAV).
  ///
  /// Returns the duration in milliseconds, or 0 if the file doesn't exist.
  Future<int> getAudioDurationMs(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return 0;

      var size = await file.length();

      // If WAV, subtract header
      final data = await file.readAsBytes();
      if (size >= 44 &&
          data[0] == 0x52 &&
          data[1] == 0x49 &&
          data[2] == 0x46 &&
          data[3] == 0x46) {
        size -= 44;
      }

      // Calculate duration: bytes / (sampleRate * channels * bytesPerSample) * 1000
      final bytesPerSecond = AudioConstants.byteRate;
      return (size / bytesPerSecond * 1000).round();
    } catch (e) {
      _logger.w('AudioLocalDataSource: Could not calculate duration for $filePath');
      return 0;
    }
  }

  /// Find the offset of the PCM data within a WAV file.
  ///
  /// Searches for the 'data' subchunk and returns its payload offset.
  /// Defaults to 44 (standard WAV header size) if not found.
  int _findDataChunkOffset(Uint8List wavData) {
    for (var i = 36; i < wavData.length - 8; i++) {
      if (wavData[i] == 0x64 && // d
          wavData[i + 1] == 0x61 && // a
          wavData[i + 2] == 0x74 && // t
          wavData[i + 3] == 0x61) {
        // a
        return i + 8;
      }
    }
    return 44;
  }
}
