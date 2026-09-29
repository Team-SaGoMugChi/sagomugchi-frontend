/// Step3 영상 생성 작업 상태 — 서버 `VideoJobStatus`와 1:1 대응
/// (`POST /video/jobs`, `GET /video/jobs/{id}` 응답).
enum VideoJobState {
  running,
  done,
  failed;

  static VideoJobState fromJson(Object? value) => switch (value) {
    'done' => VideoJobState.done,
    'failed' => VideoJobState.failed,
    _ => VideoJobState.running,
  };
}

class VideoJobStatus {
  const VideoJobStatus({
    required this.jobId,
    required this.state,
    required this.stage,
    required this.progress,
    this.error,
    this.videoUrl,
  });

  final String jobId;
  final VideoJobState state;

  /// 서버 단계 이름 — storyboard / images / videos / narration / compose / done.
  final String stage;

  /// 0~1. 로딩 화면 진행 바에 그대로 쓴다.
  final double progress;

  /// [state]가 failed일 때 사용자에게 보여줄 서버 메시지.
  final String? error;

  /// [state]가 done일 때 재생할 mp4의 절대 URL. 데이터소스가 서버의 상대
  /// 경로를 base URL과 합쳐 채운다. 더미 모드에서는 null(재생할 파일 없음).
  final String? videoUrl;

  bool get isDone => state == VideoJobState.done;
  bool get isFailed => state == VideoJobState.failed;

  factory VideoJobStatus.fromJson(
    Map<String, dynamic> json, {
    required String baseUrl,
  }) {
    final path = json['video_url'] as String?;
    return VideoJobStatus(
      jobId: json['job_id'] as String,
      state: VideoJobState.fromJson(json['status']),
      stage: json['stage'] as String? ?? 'storyboard',
      progress: ((json['progress'] as num?) ?? 0).toDouble().clamp(0, 1),
      error: json['error'] as String?,
      videoUrl: path == null
          ? null
          : Uri.parse(baseUrl).resolve(path).toString(),
    );
  }
}
