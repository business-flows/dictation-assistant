import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../../../../core/constants/llm_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../services/app_database.dart';
import '../../domain/entities/refinement_result_entity.dart';
import '../../domain/repositories/i_llm_repository.dart';
import '../datasources/remote/llm_remote_datasource.dart';
import '../models/refinement_request_model.dart';

/// Implementation of [ILLMRepository] that communicates with an
/// OpenAI-compatible LLM API endpoint.
///
/// Handles both streaming and non-streaming refinement requests,
/// configuration management, and error mapping from HTTP exceptions
/// to domain [Failure] objects.
class LlmRepositoryImpl implements ILLMRepository {
  final LlmRemoteDataSource _remoteDataSource;
  final AppDatabase _database;
  final Dio _dio;
  final Logger _logger;

  // In-memory cache for configuration to avoid repeated DB lookups
  LlmConfig? _cachedConfig;

  /// Creates [LlmRepositoryImpl] with required dependencies.
  LlmRepositoryImpl({
    required LlmRemoteDataSource remoteDataSource,
    required AppDatabase database,
    required Dio dio,
    Logger? logger,
  })  : _remoteDataSource = remoteDataSource,
        _database = database,
        _dio = dio,
        _logger = logger ?? Logger();

  @override
  Stream<Either<Failure, String>> refineTextStream({
    required String text,
    required String languageCode,
    String? customPrompt,
  }) async* {
    final stopwatch = Stopwatch()..start();
    final configResult = await getConfiguration();

    yield* configResult.fold(
      (failure) async* {
        yield Left(failure);
      },
      (config) async* {
        try {
          final request = RefinementRequestModel(
            text: text,
            languageCode: languageCode,
            customPrompt: customPrompt,
          );

          final messages = _buildMessages(request, config);
          final tokenStream = await _remoteDataSource.streamChatCompletion(
            config: config,
            messages: messages,
          );

          await for (final token in tokenStream) {
            yield Right(token);
          }

          stopwatch.stop();
          _logger.i(
            'Streaming refinement completed in ${stopwatch.elapsed.inMilliseconds}ms',
          );
        } on LLMApiException catch (e) {
          stopwatch.stop();
          _logger.e('LLM API error: ${e.message}');
          yield Left(_mapExceptionToFailure(e));
        } catch (e, stackTrace) {
          stopwatch.stop();
          _logger.e('Unexpected error during refinement: $e', error: e, stackTrace: stackTrace);
          yield Left(UnexpectedFailure('Unexpected error: $e'));
        }
      },
    );
  }

  @override
  Future<Either<Failure, RefinementResultEntity>> refineText({
    required String text,
    required String languageCode,
    String? customPrompt,
  }) async {
    final stopwatch = Stopwatch()..start();
    final configResult = await getConfiguration();

    return configResult.fold(
      (failure) => Left(failure),
      (config) async {
        try {
          final request = RefinementRequestModel(
            text: text,
            languageCode: languageCode,
            customPrompt: customPrompt,
          );

          final messages = _buildMessages(request, config);
          final refinedText = await _remoteDataSource.chatCompletion(
            config: config,
            messages: messages,
          );

          stopwatch.stop();
          _logger.i(
            'Refinement completed in ${stopwatch.elapsed.inMilliseconds}ms',
          );

          return Right(RefinementResultEntity(
            originalText: text,
            refinedText: refinedText,
            refinedAt: DateTime.now().toUtc(),
            modelUsed: config.modelName,
            processingTime: stopwatch.elapsed,
          ));
        } on LLMApiException catch (e) {
          stopwatch.stop();
          _logger.e('LLM API error: ${e.message}');
          return Left(_mapExceptionToFailure(e));
        } catch (e, stackTrace) {
          stopwatch.stop();
          _logger.e('Unexpected error: $e', error: e, stackTrace: stackTrace);
          return Left(UnexpectedFailure('Unexpected error: $e'));
        }
      },
    );
  }

  @override
  Future<Either<Failure, bool>> validateConfiguration() async {
    final configResult = await getConfiguration();

    return configResult.fold(
      (failure) => Left(failure),
      (config) async {
        try {
          final isValid = await _remoteDataSource.validateConfiguration(config);
          return Right(isValid);
        } on LLMApiException catch (e) {
          _logger.w('Configuration validation failed: ${e.message}');
          return Right(false);
        } catch (e) {
          _logger.w('Configuration validation error: $e');
          return Right(false);
        }
      },
    );
  }

  @override
  Future<Either<Failure, LlmConfig>> getConfiguration() async {
    try {
      // Return cached config if available
      if (_cachedConfig != null) {
        return Right(_cachedConfig!);
      }

      final settings = await _database.getSettings();

      if (settings == null) {
        return Left(CacheFailure('No settings found in database'));
      }

      final endpointUrl = settings.llmEndpointUrl;
      final modelName = settings.llmModelName;

      if (endpointUrl == null || endpointUrl.isEmpty) {
        return Left(ValidationFailure(
          'LLM endpoint URL not configured. Please set it in Settings.',
          code: 'ENDPOINT_NOT_CONFIGURED',
        ));
      }

      if (modelName == null || modelName.isEmpty) {
        return Left(ValidationFailure(
          'LLM model name not configured. Please set it in Settings.',
          code: 'MODEL_NOT_CONFIGURED',
        ));
      }

      // API token is stored in secure storage; for now, we pass null
      // and the datasource will use whatever is configured
      final config = LlmConfig(
        endpointUrl: endpointUrl,
        apiToken: null, // Retrieved from secure storage by caller
        modelName: modelName,
        systemPrompt:
            settings.llmSystemPrompt ?? LlmConstants.defaultSystemPrompt,
        temperature: LlmConstants.defaultTemperature,
        maxTokens: LlmConstants.defaultMaxTokens,
      );

      _cachedConfig = config;
      return Right(config);
    } catch (e) {
      _logger.e('Failed to get LLM configuration: $e');
      return Left(CacheFailure('Failed to load configuration: $e'));
    }
  }

  /// Clears the cached configuration, forcing a reload on next access.
  void clearCache() {
    _cachedConfig = null;
  }

  // ---- Private helpers ----

  /// Builds the messages list from the request model and config.
  List<Map<String, String>> _buildMessages(
    RefinementRequestModel request,
    LlmConfig config,
  ) {
    final effectivePrompt = request.customPrompt ?? config.systemPrompt;
    final languageInstruction = _getLanguageInstruction(request.languageCode);
    final fullSystemPrompt = '$effectivePrompt\n$languageInstruction';

    return [
      {'role': 'system', 'content': fullSystemPrompt},
      {'role': 'user', 'content': request.text},
    ];
  }

  /// Gets a language-specific instruction for the system prompt.
  String _getLanguageInstruction(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'ar':
        return 'الم dictateة باللغة العربية. حافظ على اللغة العربية.';
      case 'fr':
        return 'La dictation est en francais. Preservez la langue.';
      case 'en':
      default:
        return 'The dictation is in English. Preserve English.';
    }
  }

  /// Maps [LLMApiException] to domain [Failure] types.
  Failure _mapExceptionToFailure(LLMApiException exception) {
    switch (exception.code) {
      case 'INVALID_API_KEY':
        return ServerFailure(
          exception.message,
          statusCode: exception.statusCode,
          code: exception.code,
        );
      case 'RATE_LIMIT':
        return ServerFailure(
          exception.message,
          statusCode: exception.statusCode,
          code: exception.code,
        );
      case 'MODEL_NOT_FOUND':
        return ValidationFailure(exception.message, code: exception.code);
      case 'TIMEOUT':
      case 'CONNECTION_ERROR':
        return NetworkFailure(exception.message, code: exception.code);
      case 'SERVER_ERROR':
        return ServerFailure(
          exception.message,
          statusCode: exception.statusCode,
          code: exception.code,
        );
      default:
        return UnexpectedFailure(exception.message, code: exception.code);
    }
  }
}
