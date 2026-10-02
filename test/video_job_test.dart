import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/error/app_exception.dart';
import 'package:oddo/core/network/api_client.dart';
import 'package:oddo/features/diary/application/diary_draft_provider.dart';
import 'package:oddo/features/diary/application/video_job_controller.dart';
import 'package:oddo/features/diary/data/datasources/video_remote_data_source.dart';
import 'package:oddo/features/diary/data/diary_providers.dart';
import 'package:oddo/features/diary/data/models/fusion_result.dart';
import 'package:oddo/features/diary/data/models/video_job_status.dart';
import 'package:oddo/features/diary/data/repositories/video_repository.dart';

class _Client implements ApiClient {
  String? path;
  Object? body;

  @override
  Future<Map<String, dynamic>> post(String path, {Object? body}) async {
    this.path = path;
    this.body = body;
    return {
      'job_id': 'abc',
      'status': 'running',
      'stage': 'storyboard',
      'progress': 0.0,
    };
  }

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    this.path = path;
    return {
      'job_id': 'abc',
      'status': 'done',
      'stage': 'done',
      'progress': 1.0,
      'video_url': '/video/jobs/abc/file',
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 등록 후 [pollsUntilDone]번째 폴링에서 끝나는 가짜 서버.
class _Repository implements VideoRepository {
  _Repository({this.pollsUntilDone = 2, this.failWith});

  final int pollsUntilDone;
  final Object? failWith;
  int created = 0;
  int polls = 0;
  Map<String, Object?>? sent;

  @override
  Future<VideoJobStatus> createJob({
    required String text,
    List<String>? emotionKeywords,
    Map<String, double>? emotionScores,
    int? emotionIntensity,
    Map<String, dynamic>? diaryHandoff,
  }) async {
    created++;
    sent = {
      'text': text,
      'emotionKeywords': emotionKeywords,
      'emotionIntensity': emotionIntensity,
    };
    return _status(VideoJobState.running, 0);
  }

  @override
  Future<VideoJobStatus> fetchJob(String jobId) async {
    if (failWith != null) throw failWith!;
    polls++;
    return polls >= pollsUntilDone
        ? const VideoJobStatus(
            jobId: 'job',
            state: VideoJobState.done,
            stage: 'done',
            progress: 1,
            videoUrl: 'http://server/video/jobs/job/file',
          )
        : _status(VideoJobState.running, polls / pollsUntilDone);
  }

  VideoJobStatus _status(VideoJobState state, double progress) =>
      VideoJobStatus(
        jobId: 'job',
        state: state,
        stage: 'videos',
        progress: progress,
      );
}

const _fusion = FusionResult(
  emotionKeywords: ['슬픔', '분노'],
  emotionScores: {'슬픔': 62, '분노': 21},
  emotionIntensity: 58,
  textEmotionScores: {'슬픔': 0.62},
  voiceDelta: {},
  faceDelta: {},
);

ProviderContainer _container(VideoRepository repository, {String? text}) {
  final container = ProviderContainer(
    overrides: [videoRepositoryProvider.overrideWithValue(repository)],
  );
  if (text != null) {
    container.read(diaryDraftProvider.notifier)
      ..setTranscript(text)
      ..setFusionResult(_fusion);
  }
  return container;
}

void main() {
  group('VideoRemoteDataSource', () {
    test('Step2 결과를 snake_case로 보내고 영상 경로를 절대 URL로 만든다', () async {
      final client = _Client();
      final source = VideoRemoteDataSource(
        client,
        baseUrl: 'http://10.0.2.2:8001',
      );

      final created = await source.createJob(
        text: '오늘 있었던 일',
        emotionKeywords: ['슬픔'],
        emotionScores: {'슬픔': 62},
        emotionIntensity: 58,
      );
      expect(client.path, '/video/jobs');
      expect(client.body, {
        'text': '오늘 있었던 일',
        'emotion_keywords': ['슬픔'],
        'emotion_scores': {'슬픔': 62},
        'emotion_intensity': 58,
      });
      expect(created.state, VideoJobState.running);
      expect(created.videoUrl, isNull);

      final done = await source.fetchJob('abc');
      expect(client.path, '/video/jobs/abc');
      expect(done.isDone, isTrue);
      expect(done.videoUrl, 'http://10.0.2.2:8001/video/jobs/abc/file');
    });

    test('감정 값이 없으면 원문만 보낸다', () async {
      final client = _Client();
      await VideoRemoteDataSource(
        client,
        baseUrl: 'http://x',
      ).createJob(text: '원문');
      expect(client.body, {'text': '원문'});
    });
  });

  group('VideoJobController', () {
    testWidgets('작업을 등록하고 끝날 때까지 폴링한다', (tester) async {
      final repository = _Repository();
      final container = _container(repository, text: '오늘 회의에서 있었던 일');
      addTearDown(container.dispose);
      final controller = container.read(videoJobControllerProvider.notifier);

      await controller.start();
      expect(repository.sent, {
        'text': '오늘 회의에서 있었던 일',
        'emotionKeywords': ['슬픔', '분노'],
        'emotionIntensity': 58,
      });
      expect(container.read(videoJobControllerProvider).isDone, isFalse);

      await tester.pump(VideoJobController.pollInterval);
      expect(container.read(videoJobControllerProvider).job!.progress, 0.5);

      await tester.pump(VideoJobController.pollInterval);
      final state = container.read(videoJobControllerProvider);
      expect(state.isDone, isTrue);
      expect(state.videoUrl, 'http://server/video/jobs/job/file');

      // 끝난 뒤에는 더 폴링하지 않는다.
      await tester.pump(VideoJobController.pollInterval * 3);
      expect(repository.polls, 2);
    });

    testWidgets('같은 원문으로 다시 들어오면 새 작업을 만들지 않는다', (tester) async {
      final repository = _Repository(pollsUntilDone: 1);
      final container = _container(repository, text: '같은 일기');
      addTearDown(container.dispose);
      final controller = container.read(videoJobControllerProvider.notifier);

      await controller.start();
      await tester.pump(VideoJobController.pollInterval);
      await controller.start();

      expect(repository.created, 1);
    });

    testWidgets('폴링이 연달아 끊기면 실패로 보여주고 재시도할 수 있다', (tester) async {
      final repository = _Repository(failWith: const NetworkException());
      final container = _container(repository, text: '일기');
      addTearDown(container.dispose);
      final controller = container.read(videoJobControllerProvider.notifier);

      await controller.start();
      for (var i = 0; i < VideoJobController.maxPollFailures - 1; i++) {
        await tester.pump(VideoJobController.pollInterval);
        expect(container.read(videoJobControllerProvider).isFailed, isFalse);
      }
      await tester.pump(VideoJobController.pollInterval);
      expect(container.read(videoJobControllerProvider).isFailed, isTrue);

      await controller.retry();
      expect(repository.created, 2);
      expect(container.read(videoJobControllerProvider).isFailed, isFalse);

      // 재시도한 작업은 폴링 중이다. 타이머 검사 전에 정리한다.
      container.dispose();
    });

    testWidgets('원문이 없으면 서버를 부르지 않고 실패한다', (tester) async {
      final repository = _Repository();
      final container = _container(repository);
      addTearDown(container.dispose);

      await container.read(videoJobControllerProvider.notifier).start();

      expect(repository.created, 0);
      expect(container.read(videoJobControllerProvider).isFailed, isTrue);
    });
  });
}
