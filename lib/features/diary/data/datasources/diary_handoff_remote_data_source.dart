import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/date_formatter.dart';
import '../models/diary_handoff.dart';
import '../models/diary_interview.dart';
import '../models/fusion_result.dart';
import 'diary_handoff_data_source.dart';

/// 서버가 JSON을 만들고, 저장은 앱이 사용자 권한으로 한다 — 서버는 요청한
/// 사용자를 확인하지 않으므로 대신 쓰지 않는다(`firestore.rules`는 본인 문서만 허용).
class DiaryHandoffRemoteDataSource implements DiaryHandoffDataSource {
  DiaryHandoffRemoteDataSource(
    this._apiClient, {
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth,
       _firestore = firestore;

  final ApiClient _apiClient;
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;

  @override
  Future<DiaryHandoff> build({
    required DateTime date,
    required String transcript,
    String? diaryText,
    String? summary,
    Map<String, String?> slots = const {},
    List<InterviewMessage> conversation = const [],
    FusionResult? emotion,
  }) async {
    // 서버(JSON)는 snake_case, 앱은 camelCase — 변환은 여기서만 한다.
    final json = await _apiClient.post(
      '/diary/handoff',
      body: {
        'date': DateFormatter.dateKey(date),
        'transcript': transcript,
        'diary_text': ?diaryText,
        'summary': ?summary,
        'slots': slots,
        'conversation': [for (final m in conversation) m.toJson()],
        if (emotion != null)
          'emotion': {
            'keywords': emotion.emotionKeywords,
            'scores': emotion.emotionScores,
            'intensity': emotion.emotionIntensity,
            'signals': emotion.signals,
            'incongruent': emotion.incongruent,
          },
      },
    );
    final video = json['video'];
    final counsel = json['counsel'];
    if (video is! Map<String, dynamic> || counsel is! Map<String, dynamic>) {
      throw const ServerException('전달 파일을 만들지 못했어요.');
    }
    return DiaryHandoff(video: video, counsel: counsel);
  }

  @override
  Future<void> save({
    required DateTime date,
    required DiaryHandoff handoff,
  }) async {
    final uid = (_auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (uid == null) {
      throw const AuthException('로그인이 필요해요. 다시 로그인해주세요.');
    }
    try {
      await (_firestore ?? FirebaseFirestore.instance)
          .collection('users')
          .doc(uid)
          .collection('handoffs')
          .doc(DateFormatter.dateKey(date))
          .set({
            'video': handoff.video,
            'counsel': handoff.counsel,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
          });
    } on FirebaseException catch (e) {
      throw ServerException('전달 파일을 저장하지 못했어요.', e);
    }
  }
}
