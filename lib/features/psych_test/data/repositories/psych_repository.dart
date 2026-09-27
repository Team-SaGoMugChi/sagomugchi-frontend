import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/app_exception.dart';
import '../models/psych_result.dart';

abstract interface class PsychRepository {
  Future<PsychResult?> fetchResult();

  Future<void> saveBig5({
    required Map<String, int> scores,
    required String instrument,
    required DateTime completedAt,
  });
}

class PsychFirestoreRepository implements PsychRepository {
  PsychFirestoreRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AuthException('로그인이 필요해요. 다시 로그인해주세요.');
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc('psych');
  }

  @override
  Future<PsychResult?> fetchResult() => _guard(() async {
    final snapshot = await _doc.get();
    final data = snapshot.data();
    return data == null ? null : PsychResult.fromJson(data);
  });

  @override
  Future<void> saveBig5({
    required Map<String, int> scores,
    required String instrument,
    required DateTime completedAt,
  }) => _guard(
    () => _doc.set({
      'big5': scores,
      'big5Instrument': instrument,
      'big5CompletedAt': completedAt.toIso8601String(),
      'updatedAt': completedAt.toIso8601String(),
    }, SetOptions(merge: true)),
  );

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on FirebaseException catch (error) {
      if (error.code == 'unavailable') {
        throw NetworkException('네트워크 연결이 불안정해요.', error);
      }
      throw ServerException('검사 결과를 저장하지 못했어요. 잠시 후 다시 시도해주세요.', error);
    }
  }
}

class PsychDummyRepository implements PsychRepository {
  PsychResult? _result;

  @override
  Future<PsychResult?> fetchResult() async => _result;

  @override
  Future<void> saveBig5({
    required Map<String, int> scores,
    required String instrument,
    required DateTime completedAt,
  }) async {
    _result = (_result ?? PsychResult(updatedAt: completedAt)).copyWith(
      big5: scores,
      big5Instrument: instrument,
      big5CompletedAt: completedAt,
      updatedAt: completedAt,
    );
  }
}
