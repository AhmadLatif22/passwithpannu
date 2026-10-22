
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class HomeVideoBanner extends StatefulWidget {
  const HomeVideoBanner({super.key});

  @override
  State<HomeVideoBanner> createState() => _HomeVideoBannerState();
}

class _HomeVideoBannerState extends State<HomeVideoBanner> {
  late final VideoPlayerController _controller;
  bool _isReady = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset(
      'assets/videos/driving_intro.mp4',
    );

    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      await _controller.setVolume(0);
      await _controller.play();

      if (mounted) {
        setState(() => _isReady = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: const Color(0xFF171B28),
              child: _isReady
                  ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              )
                  : Center(
                child: _hasError
                    ? const Icon(
                  Icons.videocam_off_outlined,
                  color: Colors.white54,
                  size: 32,
                )
                    : const CircularProgressIndicator(
                  color: Color(0xFF18D67B),
                ),
              ),
            ),

            // Subtle dark gradient for premium appearance
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x990B0D14),
                    ],
                  ),
                ),
              ),
            ),

            // Branding
            // const Positioned(
            //   left: 16,
            //   bottom: 16,
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       Text(
            //         'PASS WITH PANNU',
            //         style: TextStyle(
            //           color: Colors.white,
            //           fontSize: 18,
            //           fontWeight: FontWeight.w800,
            //           letterSpacing: 1.2,
            //         ),
            //       ),
            //       SizedBox(height: 4),
            //       Text(
            //         'Your journey to driving confidence',
            //         style: TextStyle(
            //           color: Color(0xFFE0E6F0),
            //           fontSize: 12,
            //         ),
            //       ),
            //     ],
            //   ),
            // ),

            // Play/pause control
            // if (_isReady)
            //   Positioned(
            //     right: 12,
            //     bottom: 12,
            //     child: IconButton.filledTonal(
            //       tooltip: _controller.value.isPlaying
            //           ? 'Pause video'
            //           : 'Play video',
            //       onPressed: () async {
            //         if (_controller.value.isPlaying) {
            //           await _controller.pause();
            //         } else {
            //           await _controller.play();
            //         }
            //
            //         if (mounted) setState(() {});
            //       },
            //       icon: Icon(
            //         _controller.value.isPlaying
            //             ? Icons.pause_rounded
            //             : Icons.play_arrow_rounded,
            //       ),
            //     ),
            //   ),
          ],
        ),
      ),
    );
  }
}
