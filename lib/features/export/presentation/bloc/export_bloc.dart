import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants/app_constants.dart';
import '../../data/datasources/platform/file_picker_datasource.dart';
import '../../domain/entities/export_options_entity.dart';
import '../../domain/usecases/copy_to_clipboard.dart';
import '../../domain/usecases/export_to_docx.dart';
import '../../domain/usecases/share_text.dart';
import 'export_event.dart';
import 'export_state.dart';

/// BLoC that manages the export lifecycle.
///
/// Coordinates between the UI and the domain layer to:
/// - Export text/sessions to DOCX format
/// - Copy text to the system clipboard
/// - Share text via the platform share sheet
/// - Pick save locations using native file dialogs
///
/// Usage:
/// ```dart
/// BlocProvider(
///   create: (context) => ExportBloc(
///     exportToDocx: getIt<ExportToDocx>(),
///     copyToClipboard: getIt<CopyToClipboard>(),
///     shareText: getIt<ShareText>(),
///     filePicker: getIt<FilePickerDataSource>(),
///   ),
///   child: ExportOptionsSheet(...),
/// )
/// ```
class ExportBloc extends Bloc<ExportEvent, ExportState> {
  final ExportToDocx _exportToDocx;
  final CopyToClipboard _copyToClipboard;
  final ShareText _shareText;
  final FilePickerDataSource _filePicker;
  final Logger _logger;

  ExportBloc({
    required ExportToDocx exportToDocx,
    required CopyToClipboard copyToClipboard,
    required ShareText shareText,
    required FilePickerDataSource filePicker,
    Logger? logger,
  })  : _exportToDocx = exportToDocx,
        _copyToClipboard = copyToClipboard,
        _shareText = shareText,
        _filePicker = filePicker,
        _logger = logger ?? Logger(),
        super(const ExportInitial()) {
    on<ExportToDocx>(_onExportToDocx);
    on<PickExportLocation>(_onPickExportLocation);
    on<ExportSession>(_onExportSession);
    on<CopyToClipboard>(_onCopyToClipboard);
    on<ShareText>(_onShareText);
    on<ResetExport>(_onResetExport);
  }

  /// Handles direct DOCX export to a known path.
  Future<void> _onExportToDocx(
    ExportToDocx event,
    Emitter<ExportState> emit,
  ) async {
    emit(const ExportInProgress());

    final result = await _exportToDocx(ExportToDocxParams(
      sessionId: event.sessionId,
      text: event.text,
      options: event.options,
      savePath: event.savePath,
    ));

    result.fold(
      (failure) {
        _logger.w('Export failed: ${failure.message}');
        emit(ExportError(message: failure.message));
      },
      (filePath) {
        _logger.i('Export completed: $filePath');
        emit(ExportCompleted(filePath: filePath));
      },
    );
  }

  /// Handles picking a save location then exporting.
  Future<void> _onPickExportLocation(
    PickExportLocation event,
    Emitter<ExportState> emit,
  ) async {
    emit(const ExportInProgress());

    // Pick save location
    final pickedPath = await _filePicker.pickSaveLocation(
      suggestedName: event.suggestedName ??
          'dictation_${_formatDateForFilename(DateTime.now())}${AppConstants.docxExtension}',
      allowedExtensions: ['docx'],
    );

    if (pickedPath == null) {
      _logger.d('User cancelled file picker');
      emit(const ExportCancelled());
      return;
    }

    // Ensure .docx extension
    String savePath = pickedPath;
    if (!savePath.toLowerCase().endsWith(AppConstants.docxExtension)) {
      savePath = '$savePath${AppConstants.docxExtension}';
    }

    // Proceed with export
    final result = await _exportToDocx(ExportToDocxParams(
      sessionId: event.sessionId,
      text: event.text,
      options: event.options,
      savePath: savePath,
    ));

    result.fold(
      (failure) {
        _logger.w('Export failed: ${failure.message}');
        emit(ExportError(message: failure.message));
      },
      (filePath) {
        _logger.i('Export completed: $filePath');
        emit(ExportCompleted(filePath: filePath));
      },
    );
  }

  /// Handles exporting a complete session.
  Future<void> _onExportSession(
    ExportSession event,
    Emitter<ExportState> emit,
  ) async {
    emit(const ExportInProgress());

    final effectiveText = event.session.getEffectiveText(
      preferRefined: true,
    );

    final result = await _exportToDocx(ExportToDocxParams(
      sessionId: event.session.id,
      text: effectiveText,
      options: ExportOptionsEntity(
        useRefinedText: event.session.hasRefinedText,
        includeMetadata: true,
      ),
      savePath: event.savePath,
    ));

    result.fold(
      (failure) {
        _logger.w('Session export failed: ${failure.message}');
        emit(ExportError(message: failure.message));
      },
      (filePath) {
        _logger.i('Session export completed: $filePath');
        emit(ExportCompleted(filePath: filePath));
      },
    );
  }

  /// Handles copying text to the clipboard.
  Future<void> _onCopyToClipboard(
    CopyToClipboard event,
    Emitter<ExportState> emit,
  ) async {
    final result = await _copyToClipboard(CopyToClipboardParams(
      text: event.text,
    ));

    result.fold(
      (failure) {
        _logger.w('Copy to clipboard failed: ${failure.message}');
        emit(ExportError(message: failure.message));
      },
      (_) {
        _logger.i('Text copied to clipboard');
        emit(const ClipboardCopied());
      },
    );
  }

  /// Handles sharing text via the platform share sheet.
  Future<void> _onShareText(
    ShareText event,
    Emitter<ExportState> emit,
  ) async {
    final result = await _shareText(ShareTextParams(
      text: event.text,
      subject: event.subject,
    ));

    result.fold(
      (failure) {
        _logger.w('Share failed: ${failure.message}');
        emit(ExportError(message: failure.message));
      },
      (_) {
        _logger.i('Text shared');
        emit(const TextShared());
      },
    );
  }

  /// Resets the export state to initial.
  Future<void> _onResetExport(
    ResetExport event,
    Emitter<ExportState> emit,
  ) async {
    emit(const ExportInitial());
  }

  /// Formats a date for use in filenames.
  String _formatDateForFilename(DateTime date) {
    final d = date.toLocal();
    return '${d.year}${_pad(d.month)}${_pad(d.day)}_${_pad(d.hour)}${_pad(d.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
