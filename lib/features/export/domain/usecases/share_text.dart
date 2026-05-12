import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';

/// Use case for sharing text via the platform share sheet.
///
/// Opens the native share dialog allowing the user to send the
/// text to other applications (email, messaging, notes, etc.).
///
/// Example:
/// ```dart
/// final result = await shareText(ShareTextParams(
///   text: session.transcribedText,
///   subject: 'Dictation from ${session.formattedDate}',
/// ));
/// ```
class ShareText implements UseCase<Unit, ShareTextParams> {
  const ShareText();

  @override
  Future<Either<Failure, Unit>> call(ShareTextParams params) async {
    try {
      await Share.share(
        params.text,
        subject: params.subject,
      );
      return const Right(unit);
    } catch (e) {
      return Left(UnexpectedFailure('Failed to share text: $e'));
    }
  }
}

/// Parameters for [ShareText] use case.
class ShareTextParams extends Equatable {
  /// The text content to share.
  final String text;

  /// Optional subject line (used for email sharing).
  final String? subject;

  const ShareTextParams({
    required this.text,
    this.subject,
  });

  @override
  List<Object?> get props => [text, subject];
}
