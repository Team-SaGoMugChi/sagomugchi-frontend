import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/error/app_exception.dart';
import 'package:oddo/features/diary/data/datasources/video_archive_dummy_data_source.dart';
import 'package:oddo/features/diary/data/datasources/video_archive_firebase_data_source.dart';
import 'package:oddo/features/diary/data/diary_providers.dart';
import 'package:oddo/features/diary/data/models/counsel_session.dart';
import 'package:oddo/features/diary/data/models/diary_entry.dart';
import 'package:oddo/features/diary/data/models/emotion_report.dart';
import 'package:oddo/features/diary/data/repositories/diary_repository.dart';
import 'package:oddo/features/diary/data/repositories/video_archive_repository.dart';

final _day = DateTime(2026, 10, 7);

class _Diary implements DiaryRepository {
  _Diary(this.videoUrl);

  final String? videoUrl;

  @override
  Future<DiaryEntry?> fetchEntry(DateTime date) async => DiaryEntry(
    id: '2026-10-07',
    date: date,
    transcript: '원문',
    summary: '요약',
    emotionKeywords: const [],
    videoUrl: videoUrl,
  );

  @override
  Future<void> saveRecord({
    required DiaryEntry entry,
    required EmotionReport report,
    required CounselSession counsel,
  }) async {}

  @override
  Future<List<DiaryEntry>> fetchEntries() async => const [];

  @override
  Future<EmotionReport?> fetchReport(DateTime date) async => null;

  @override
  Future<CounselSession?> fetchCounsel(DateTime date) async => null;

  @override
  Future<Set<DateTime>> fetchRecordedDates() async => {};
}

class _Archive implements VideoArchiveRepository {
  _Archive({this.fail = false});

  final bool fail;

  @override
  Future<String> archive({
    required DateTime date,
    required String sourceUrl,
    String? thumbnailUrl,
  }) => throw UnimplementedError();

  @override
  Future<String> playableUrl(String storagePath) async {
    if (fail) throw const ServerException('영상을 불러오지 못했어요.');
    return 'https://firebasestorage/$storagePath?token=t';
  }

  @override
  Future<String?> thumbnailUrl(String storagePath) async {
    if (fail) throw const ServerException('썸네일을 불러오지 못했어요.');
    return 'https://firebasestorage/${storagePath.replaceAll('.mp4', '.jpg')}?token=t';
  }
}

Future<String?> _savedThumbnail(String? path, {bool fail = false}) {
  final container = ProviderContainer(
    overrides: [
      diaryRepositoryProvider.overrideWithValue(_Diary(path)),
      videoArchiveRepositoryProvider.overrideWithValue(_Archive(fail: fail)),
    ],
  );
  addTearDown(container.dispose);
  return container.read(savedVideoThumbnailUrlProvider(_day).future);
}

Future<String?> _savedUrl(String? path, {bool fail = false}) {
  final container = ProviderContainer(
    overrides: [
      diaryRepositoryProvider.overrideWithValue(_Diary(path)),
      videoArchiveRepositoryProvider.overrideWithValue(_Archive(fail: fail)),
    ],
  );
  addTearDown(container.dispose);
  return container.read(savedVideoUrlProvider(_day).future);
}

void main() {
  group('savedVideoUrlProvider — 홈에서 지난 영상 재생', () {
    test('일기에 보관된 경로를 재생 주소로 바꾼다', () async {
      expect(
        await _savedUrl('users/u1/videos/2026-10-07.mp4'),
        'https://firebasestorage/users/u1/videos/2026-10-07.mp4?token=t',
      );
    });

    test('보관된 영상이 없으면 null — 플레이어가 "저장된 영상이 없어요"를 보여준다', () async {
      expect(await _savedUrl(null), isNull);
      expect(await _savedUrl(''), isNull);
    });

    test('주소를 받지 못해도 화면이 깨지지 않게 null', () async {
      expect(await _savedUrl('users/u1/videos/x.mp4', fail: true), isNull);
    });
  });

  group('savedVideoThumbnailUrlProvider — 홈 카드 썸네일', () {
    test('영상과 같은 이름의 jpg 주소', () async {
      expect(
        await _savedThumbnail('users/u1/videos/2026-10-07.mp4'),
        'https://firebasestorage/users/u1/videos/2026-10-07.jpg?token=t',
      );
    });

    test('영상이 없거나 썸네일을 못 받으면 null — 카드는 마스코트', () async {
      expect(await _savedThumbnail(null), isNull);
      expect(
        await _savedThumbnail('users/u1/videos/x.mp4', fail: true),
        isNull,
      );
    });
  });

  group('보관 경로', () {
    test('썸네일은 영상과 같은 이름의 jpg', () {
      expect(
        VideoArchiveFirebaseDataSource.thumbnailPathFor(
          'users/u1/videos/2026-10-07.mp4',
        ),
        'users/u1/videos/2026-10-07.jpg',
      );
    });

    test('Storage 경로는 사용자·날짜별 mp4', () {
      expect(
        VideoArchiveFirebaseDataSource.pathFor('u1', _day),
        'users/u1/videos/2026-10-07.mp4',
      );
    });

    test('더미 보관소는 올린 영상을 그대로 재생한다', () async {
      final dummy = VideoArchiveDummyDataSource();
      final path = await dummy.archive(
        date: _day,
        sourceUrl: 'http://server/a.mp4',
      );
      expect(await dummy.playableUrl(path), 'http://server/a.mp4');
      expect(await dummy.thumbnailUrl(path), isNull);

      final withThumb = await dummy.archive(
        date: _day,
        sourceUrl: 'http://server/b.mp4',
        thumbnailUrl: 'http://server/b.jpg',
      );
      expect(await dummy.thumbnailUrl(withThumb), 'http://server/b.jpg');
    });
  });
}
