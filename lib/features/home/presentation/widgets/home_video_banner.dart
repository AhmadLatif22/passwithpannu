import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// The packaged video is initialized once and reused when Home is rebuilt.
/// Call prewarm() after the first Flutter frame to reduce startup delay.
class HomeVideoPreloader {
  HomeVideoPreloader._();
  static final HomeVideoPreloader instance = HomeVideoPreloader._();

  VideoPlayerController? _controller;
  Future<VideoPlayerController>? _initialization;

  Future<VideoPlayerController> get ready => _initialization ??= _start();

  void prewarm() {
    unawaited(
      ready.then<void>((_) {}).catchError((Object error) {
        debugPrint('Home video prewarm failed: $error');
      }),
    );
  }

  Future<VideoPlayerController> _start() async {
    final controller = VideoPlayerController.asset(
      'assets/videos/driving_intro.mp4',
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      return controller;
    } catch (_) {
      _controller = null;
      _initialization = null; // Allow retry on next visit.
      await controller.dispose();
      rethrow;
    }
  }

  Future<void> resume() async {
    final controller = _controller;
    if (controller != null &&
        controller.value.isInitialized &&
        !controller.value.isPlaying) {
      await controller.play();
    }
  }
}

class HomeVideoBanner extends StatefulWidget {
  const HomeVideoBanner({super.key});

  @override
  State<HomeVideoBanner> createState() => _HomeVideoBannerState();
}

class _HomeVideoBannerState extends State<HomeVideoBanner>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  late final Future<VideoPlayerController> _ready;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ready = HomeVideoPreloader.instance.ready;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(HomeVideoPreloader.instance.resume());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: FutureBuilder<VideoPlayerController>(
          future: _ready,
          builder: (context, snapshot) {
            return Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF171B28)),
                if (snapshot.hasData)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: snapshot.data!.value.size.width,
                      height: snapshot.data!.value.size.height,
                      child: VideoPlayer(snapshot.data!),
                    ),
                  )
                else
                  Center(
                    child: snapshot.hasError
                        ? const Icon(
                            Icons.videocam_off_outlined,
                            color: Colors.white54,
                            size: 32,
                          )
                        : const Icon(
                            Icons.play_circle_outline_rounded,
                            color: Colors.white70,
                            size: 42,
                          ),
                  ),
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x990B0D14)],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
