import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../../../../../core/constants/llm_constants.dart';
import '../../../../../core/errors/exceptions.dart';
import '../../../domain/repositories/i_llm_repository.dart';

/// Low-level HTTP client wrapper for LLM API communication.
///
/// Handles the raw HTTP requests and SSE (Server-Sent Events) parsing
/// for streaming responses. Uses dio for HTTP transport.
class LlmRemoteDataSource {
  final Dio _dio;
  final Logger _logger;

  /// Creates an [LlmRemoteDataSource] with the given dio instance.
  LlmRemoteDataSource({
    required Dio dio,
    Logger? logger,
  })  : _dio = dio,
        _logger = logger ?? Logger();

  /// Sends a streaming chat completion request.
  ///
  /// Returns a [Stream] of text tokens as they arrive from the LLM.
  /// The stream emits partial content from each SSE event's
  /// `choices[0].delta.content` field.
  ///
  /// The stream completes when the `[DONE]` marker is received or
  /// the connection is closed.
  ///
  /// Throws [LLMApiException] on HTTP errors (401, 429, 500+, timeouts).
  Future<Stream<String>> streamChatCompletion({
    required LlmConfig config,
    required List<Map<String, String>> messages,
  }) async {
    final requestBody = _buildRequestBody(config, messages, stream: true);
    _logger.d('Streaming request to ${config.endpointUrl}');

    try {
      final response = await _dio.post<ResponseBody>(
        '${config.endpointUrl}${LlmConstants.chatCompletionsPath}',
        data: requestBody,
        options: Options(
          headers: _buildHeaders(config),
          responseType: ResponseType.stream,
        ),
      );

      if (response.data == null) {
        throw const LLMApiException('Empty response body from LLM API');
      }

      // Transform the byte stream into a string stream of tokens
      return _parseSseStream(response.data!.stream);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Sends a non-streaming chat completion request.
  ///
  /// Returns the complete response text from the LLM.
  ///
  /// Throws [LLMApiException] on HTTP errors.
  Future<String> chatCompletion({
    required LlmConfig config,
    required List<Map<String, String>> messages,
  }) async {
    final requestBody = _buildRequestBody(config, messages, stream: false);
    _logger.d('Non-streaming request to ${config.endpointUrl}');

    try {
      final response = await _dio.post(
        '${config.endpointUrl}${LlmConstants.chatCompletionsPath}',
        data: requestBody,
        options: Options(
          headers: _buildHeaders(config),
        ),
      );

      return _parseNonStreamingResponse(response.data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Sends a validation request to test the configuration.
  ///
  /// Sends a minimal request to verify the endpoint is reachable
  /// and the API key is valid.
  Future<bool> validateConfiguration(LlmConfig config) async {
    try {
      final response = await _dio.post(
        '${config.endpointUrl}${LlmConstants.chatCompletionsPath}',
        data: {
          'model': config.modelName,
          'messages': [
            {'role': 'user', 'content': 'Hi'},
          ],
          'max_tokens': 1,
        },
        options: Options(
          headers: _buildHeaders(config),
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        return false;
      }
      if (e.response?.statusCode == 401) {
        return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ---- Private helpers ----

  /// Builds request headers with authorization.
  Map<String, String> _buildHeaders(LlmConfig config) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    };

    if (config.apiToken != null && config.apiToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${config.apiToken}';
    }

    return headers;
  }

  /// Builds the request body for chat completions.
  Map<String, dynamic> _buildRequestBody(
    LlmConfig config,
    List<Map<String, String>> messages, {
    required bool stream,
  }) {
    return {
      'model': config.modelName,
      'messages': messages,
      'stream': stream,
      'temperature': config.temperature,
      'max_tokens': config.maxTokens,
    };
  }

  /// Parses a non-streaming response into the complete text.
  String _parseNonStreamingResponse(dynamic responseData) {
    try {
      final data = responseData as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;

      if (choices == null || choices.isEmpty) {
        throw const LLMApiException('No choices in LLM response');
      }

      final firstChoice = choices[0] as Map<String, dynamic>;
      final message = firstChoice['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;

      if (content == null) {
        throw const LLMApiException('No content in LLM response message');
      }

      return content;
    } catch (e) {
      if (e is LLMApiException) rethrow;
      throw LLMApiException('Failed to parse LLM response: $e');
    }
  }

  /// Parses a Server-Sent Events byte stream into a token stream.
  ///
  /// Each SSE line starts with `data: ` followed by JSON or `[DONE]`.
  /// We extract `choices[0].delta.content` from each JSON event.
  Stream<String> _parseSseStream(Stream<Uint8List> byteStream) async* {
    final buffer = StringBuffer();
    var inDoneState = false;

    await for (final chunk in byteStream) {
      if (inDoneState) break;

      // Decode bytes and add to buffer
      final chunkString = utf8.decode(chunk, allowMalformed: true);
      buffer.write(chunkString);

      // Process complete lines from buffer
      var bufferStr = buffer.toString();
      String? remaining;

      while (bufferStr.contains('\n')) {
        final newlineIndex = bufferStr.indexOf('\n');
        final line = bufferStr.substring(0, newlineIndex).trim();
        remaining = bufferStr.substring(newlineIndex + 1);

        if (line.isNotEmpty) {
          final token = _parseSseLine(line);
          if (token == LlmConstants.sseDoneMarker) {
            inDoneState = true;
            break;
          }
          if (token != null && token.isNotEmpty) {
            yield token;
          }
        }

        bufferStr = remaining;
      }

      buffer.clear();
      if (remaining != null && remaining.isNotEmpty) {
        buffer.write(remaining);
      }
    }

    // Process any remaining content in buffer
    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty && !inDoneState) {
      final token = _parseSseLine(remaining);
      if (token != null &&
          token != LlmConstants.sseDoneMarker &&
          token.isNotEmpty) {
        yield token;
      }
    }
  }

  /// Parses a single SSE line.
  ///
  /// Returns:
  /// - The token content string if it's a data event with content
  /// - `[DONE]` constant if it's the done marker
  /// - `null` if the line should be skipped (empty, comment, etc.)
  String? _parseSseLine(String line) {
    // Skip empty lines, comments, and non-data lines
    if (line.isEmpty) return null;
    if (line.startsWith(':')) return null; // SSE comment

    // Must start with "data: " prefix
    if (!line.startsWith(LlmConstants.sseDataPrefix)) {
      return null;
    }

    final data = line.substring(LlmConstants.sseDataPrefix.length).trim();

    // Check for done marker
    if (data == LlmConstants.sseDoneMarker) {
      return LlmConstants.sseDoneMarker;
    }

    // Parse JSON to extract content
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>?;

      if (choices == null || choices.isEmpty) return null;

      final firstChoice = choices[0] as Map<String, dynamic>;
      final delta = firstChoice['delta'] as Map<String, dynamic>?;
      final content = delta?['content'] as String?;

      return content;
    } catch (e) {
      // If JSON parsing fails, the line might be malformed; skip it
      _logger.w('Failed to parse SSE data line: $e');
      return null;
    }
  }

  /// Maps Dio exceptions to domain-specific [LLMApiException]s.
  LLMApiException _mapDioError(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const LLMApiException(
          'Connection timed out. Check your network and LLM endpoint.',
          code: 'TIMEOUT',
        );
      case DioExceptionType.connectionError:
        return const LLMApiException(
          'Could not connect to LLM endpoint. Verify the URL.',
          code: 'CONNECTION_ERROR',
        );
      case DioExceptionType.badResponse:
        return _mapStatusCode(statusCode, response?.data);
      case DioExceptionType.badCertificate:
        return const LLMApiException(
          'SSL certificate error. Check your network configuration.',
          code: 'SSL_ERROR',
        );
      default:
        return LLMApiException(
          'LLM API request failed: ${error.message}',
          statusCode: statusCode,
          code: 'UNKNOWN',
        );
    }
  }

  /// Maps HTTP status codes to specific error messages.
  LLMApiException _mapStatusCode(int? statusCode, dynamic responseData) {
    final message = _extractErrorMessage(responseData);

    switch (statusCode) {
      case 401:
        return LLMApiException(
          message ?? 'Invalid API key. Check your LLM API token.',
          statusCode: statusCode,
          code: 'INVALID_API_KEY',
        );
      case 429:
        return LLMApiException(
          message ?? 'Rate limit exceeded. Please wait and try again.',
          statusCode: statusCode,
          code: 'RATE_LIMIT',
        );
      case 404:
        return LLMApiException(
          message ?? 'Model not found. Check your model name.',
          statusCode: statusCode,
          code: 'MODEL_NOT_FOUND',
        );
      case 500:
      case 502:
      case 503:
      case 504:
        return LLMApiException(
          message ?? 'LLM server error. The service may be temporarily unavailable.',
          statusCode: statusCode,
          code: 'SERVER_ERROR',
        );
      default:
        return LLMApiException(
          message ?? 'HTTP $statusCode error from LLM API',
          statusCode: statusCode,
          code: 'HTTP_ERROR',
        );
    }
  }

  /// Extracts a human-readable error message from the API response.
  String? _extractErrorMessage(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final error = responseData['error'];
      if (error is Map<String, dynamic>) {
        return error['message'] as String?;
      }
    }
    return null;
  }
}
