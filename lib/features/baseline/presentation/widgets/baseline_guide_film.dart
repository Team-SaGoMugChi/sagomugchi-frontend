import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class BaselineGuideFilm extends StatefulWidget {
  const BaselineGuideFilm({super.key});
  @override
  State<BaselineGuideFilm> createState() => _BaselineGuideFilmState();
}

class _BaselineGuideFilmState extends State<BaselineGuideFilm>
    with WidgetsBindingObserver {
  VideoPlayerController? _video;
  bool _ready = false;
  bool _active = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    final video = VideoPlayerController.asset(
      'assets/videos/baseline_intro.mp4',
    );
    _video = video;
    try {
      await video.initialize();
      if (!mounted) return;
      await video.setVolume(0);
      await video.setLooping(true);
      if (!mounted) return;
      setState(() => _ready = true);
      _sync();
    } catch (_) {
      /* Poster keeps preparation available on load failure. */
    }
  }

  void _sync() {
    if (!_ready || !mounted) return;
    final animate =
        _active &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    unawaited(_setPlayback(animate));
  }

  Future<void> _setPlayback(bool play) async {
    try {
      if (play) {
        await _video?.play();
      } else {
        await _video?.pause();
      }
    } catch (_) {
      /* A leaving screen must not surface a playback error. */
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_video?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: '휴대폰으로 얼굴과 목소리를 측정하는 방법을 보여주는 애니메이션',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: _ready ? _video!.value.aspectRatio : 1,
        child: _ready
            ? VideoPlayer(_video!)
            : Image.asset(
                'assets/images/baseline_guide_poster.png',
                fit: BoxFit.cover,
              ),
      ),
    ),
  );
}
