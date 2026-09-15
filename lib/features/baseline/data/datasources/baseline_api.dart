import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/baseline_measurement_exception.dart';
import '../models/baseline_profile.dart';

/// Baseline's upload contract, independent of Firebase document reads.
class BaselineApi {
  const BaselineApi(this._client);

  final ApiClient _client;

  Future<BaselineProfile> upload({
    required String userId,
    required String voiceFilePath,
    required String faceImagePath,
  }) async {
    try {
      final json = await _client.postMultipart(
        '/baseline',
        fields: {'user_id': userId},
        filePaths: {'voice_file': voiceFilePath, 'face_image': faceImagePath},
      );
      return BaselineProfile.fromJson({
        ...json,
        'measuredAt': json['measured_at'],
      });
    } on FileSystemException {
      throw const BaselineMeasurementException(
        '측정 파일을 찾을 수 없어요. 다시 측정해주세요.',
        code: 'missing_media',
      );
    } on ServerException catch (error) {
      final cause = error.cause;
      if (cause is DioException && cause.response?.statusCode == 422) {
        final body = cause.response?.data;
        final detail = body is Map ? body['detail'] : null;
        if (detail is Map &&
            const {
              'invalid_audio',
              'voice_not_detected',
              'invalid_face_image',
              'face_not_detected',
            }.contains(detail['code']) &&
            detail['message'] is String) {
          throw BaselineMeasurementException(
            detail['message'] as String,
            code: detail['code'] as String,
          );
        }
      }
      rethrow;
    }
  }
}
