import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/date_formatter.dart';
import 'video_archive_data_source.dart';

/// 앱이 사용자 권한으로 올린다 — `storage.rules`는 본인 경로만 허용한다.
class VideoArchiveFirebaseDataSource implements VideoArchiveDataSource {
  VideoArchiveFirebaseDataSource({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    Dio? dio,
  }) : _auth = auth,
       _storage = storage,
       _dio = dio;

  final FirebaseAuth? _auth;
  final FirebaseStorage? _storage;
  final Dio? _dio;

  FirebaseStorage get _bucket => _storage ?? FirebaseStorage.instance;

  /// 영상 경로. 다른 곳(탈퇴 시 삭제 등)과 같은 규칙을 쓰도록 한곳에 둔다.
  static String pathFor(String uid, DateTime date) =>
      'users/$uid/videos/${DateFormatter.dateKey(date)}.mp4';

  /// 영상 경로 → 같은 이름의 썸네일 경로(`.jpg`).
  static String thumbnailPathFor(String videoPath) =>
      videoPath.replaceFirst(RegExp(r'\.mp4$'), '.jpg');

  @override
  Future<String> archive({
    required DateTime date,
    required String sourceUrl,
    String? thumbnailUrl,
  }) async {
    final uid = (_auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (uid == null) {
      throw const AuthException('로그인이 필요해요. 다시 로그인해주세요.');
    }
    final bytes = await _download(sourceUrl, '영상을 받지 못했어요.');
    if (bytes.isEmpty) throw const ServerException('영상 파일이 비어 있어요.');

    final path = pathFor(uid, date);
    try {
      await _bucket
          .ref(path)
          .putData(bytes, SettableMetadata(contentType: 'video/mp4'));
    } on FirebaseException catch (e) {
      throw ServerException('영상을 보관하지 못했어요.', e);
    }
    if (thumbnailUrl != null) await _archiveThumbnail(path, thumbnailUrl);
    return path;
  }

  /// 썸네일은 홈 카드 장식이라 실패해도 영상 보관은 성공으로 둔다(카드는 마스코트로 대신).
  Future<void> _archiveThumbnail(String videoPath, String thumbnailUrl) async {
    try {
      final bytes = await _download(thumbnailUrl, '썸네일을 받지 못했어요.');
      if (bytes.isEmpty) return;
      await _bucket
          .ref(thumbnailPathFor(videoPath))
          .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    } on AppException {
      return;
    } on FirebaseException {
      return;
    }
  }

  Future<Uint8List> _download(String url, String message) async {
    try {
      final response = await (_dio ?? Dio()).get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const []);
    } on DioException catch (e) {
      throw NetworkException(message, e);
    }
  }

  @override
  Future<String> playableUrl(String storagePath) async {
    // 예전 기록이나 서버 주소가 그대로 들어간 경우.
    if (storagePath.startsWith('http')) return storagePath;
    try {
      return await _bucket.ref(storagePath).getDownloadURL();
    } on FirebaseException catch (e) {
      throw ServerException('영상을 불러오지 못했어요.', e);
    }
  }

  @override
  Future<String?> thumbnailUrl(String storagePath) async {
    if (storagePath.startsWith('http')) return null;
    try {
      return await _bucket.ref(thumbnailPathFor(storagePath)).getDownloadURL();
    } on FirebaseException {
      // 썸네일이 없는 예전 영상 등.
      return null;
    }
  }
}
