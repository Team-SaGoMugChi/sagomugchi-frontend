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

  @override
  Future<String> archive({
    required DateTime date,
    required String sourceUrl,
  }) async {
    final uid = (_auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (uid == null) {
      throw const AuthException('로그인이 필요해요. 다시 로그인해주세요.');
    }
    final Uint8List bytes;
    try {
      final response = await (_dio ?? Dio()).get<List<int>>(
        sourceUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      bytes = Uint8List.fromList(response.data ?? const []);
    } on DioException catch (e) {
      throw NetworkException('영상을 받지 못했어요.', e);
    }
    if (bytes.isEmpty) throw const ServerException('영상 파일이 비어 있어요.');

    final path = pathFor(uid, date);
    try {
      await _bucket
          .ref(path)
          .putData(bytes, SettableMetadata(contentType: 'video/mp4'));
    } on FirebaseException catch (e) {
      throw ServerException('영상을 보관하지 못했어요.', e);
    }
    return path;
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
}
