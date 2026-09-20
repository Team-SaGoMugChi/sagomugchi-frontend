import '../../../../core/error/app_exception.dart';

/// Uploading the same files again cannot recover an unusable measurement.
class BaselineMeasurementException extends AppException {
  const BaselineMeasurementException(super.message, {required this.code});

  final String code;
}
