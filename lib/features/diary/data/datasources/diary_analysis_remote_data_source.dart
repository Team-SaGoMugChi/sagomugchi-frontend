import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../baseline/data/models/baseline_profile.dart';
import '../models/fusion_result.dart';
import 'diary_analysis_data_source.dart';

/// 실제 AI 서버(`POST /stt/transcribe`, `POST /diary/step2/analyze`) 호출. baseline은 서버가 아직
/// Firestore에서 직접 읽지 않아서(step2.py TODO) 클라이언트가 함께 전달한다.
class DiaryAnalysisRemoteDataSource implements DiaryAnalysisDataSource {
  DiaryAnalysisRemoteDataSource(this._apiClient, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final ApiClient _apiClient;
  final FirebaseAuth _auth;

  @override
  Future<String> transcribe({required String voiceFilePath}) async {
    final Map<String, dynamic> json;
    try {
      json = await _apiClient.postMultipart(
        '/stt/transcribe',
        filePaths: {'voice_file': voiceFilePath},
      );
    } on ServerException catch (error) {
      // 서버가 실패 사유별로 사용자용 문구를 내려준다(재녹음 안내 422 /
      // 키 미설정·CLOVA 장애 5xx) — 있으면 그대로 보여준다.
      final cause = error.cause;
      final body = cause is DioException ? cause.response?.data : null;
      final detail = body is Map ? body['detail'] : null;
      if (detail is Map && detail['message'] is String) {
        throw ServerException(detail['message'] as String, cause);
      }
      rethrow;
    }
    final text = json['text'];
    if (text is! String) {
      throw const ServerException('음성 인식 응답을 처리하지 못했어요.');
    }
    return text;
  }

  @override
  Future<FusionResult> analyzeStep2({
    required String text,
    required String voiceFilePath,
    required String faceImagePath,
    required BaselineProfile baseline,
  }) async {
    final json = await _apiClient.postMultipart(
      '/diary/step2/analyze',
      fields: {
        'text': text,
        'baseline_voice': jsonEncode(baseline.voice),
        'baseline_face': jsonEncode(baseline.face),
        'user_id': ?_auth.currentUser?.uid,
      },
      filePaths: {'voice_file': voiceFilePath, 'face_image': faceImagePath},
    );
    try {
      return FusionResult.fromJson(json);
    } catch (e) {
      throw ServerException('감정 분석 응답을 처리하지 못했어요.', e);
    }
  }
}
