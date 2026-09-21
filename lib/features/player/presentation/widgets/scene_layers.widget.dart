import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/widgets/loading_state.widget.dart';
import '../../controller/player.controller.dart';
import '../../controller/player.provider.dart';
import '../../data/sprite_loader.service.dart';
import '../../domain/playback_clock.dart';
import '../../domain/scene.entity.dart';
import '../../domain/scene_event.scheduler.dart';
import '../../domain/scene_layer.entity.dart';

/// The smallest whole-number scale that still covers [viewport].
///
/// Whole numbers only: a fractional scale resamples the art, which is exactly
/// what makes pixel art look soft inside a video.
int sceneScaleFor({
  required Size viewport,
  required int canvasWidth,
  required int canvasHeight,
}) {
  if (canvasWidth <= 0 || canvasHeight <= 0) return 1;

  final int byWidth = (viewport.width / canvasWidth).ceil();
  final int byHeight = (viewport.height / canvasHeight).ceil();

  return math.max(1, math.max(byWidth, byHeight));
}

/// Which frame of a strip is showing at [clock].
int frameIndexAt({
  required Duration clock,
  required double fps,
  required int frameCount,
}) {
  if (frameCount <= 1 || fps <= 0) return 0;

  final int frame = (clock.inMilliseconds * fps / 1000).floor();

  return frame % frameCount;
}

/// Draws a scene as a stack of pixel-art sprite layers.
///
/// One ticker drives every layer; one painter draws them all. That is cheaper
/// than a video decoder and, unlike video, it stays sharp: the canvas is
/// scaled by a whole number, so one authored pixel is always an exact block
/// of screen pixels.
class SceneLayersView extends ConsumerStatefulWidget {
  const SceneLayersView({required this.scene, super.key});

  final SceneEntity scene;

  @override
  ConsumerState<SceneLayersView> createState() => _SceneLayersViewState();
}

class _SceneLayersViewState extends ConsumerState<SceneLayersView>
    with SingleTickerProviderStateMixin {
  /// How long the whole scene takes to drift one pixel out and back. Slow
  /// enough that nobody sees it move, fast enough that the scene never feels
  /// like a photograph.
  static const Duration _driftPeriod = Duration(seconds: 23);

  late final Ticker _ticker;

  /// Repaint signal for the painter, so the widget tree is never rebuilt.
  final ValueNotifier<int> _frameTick = ValueNotifier<int>(0);

  final Map<String, ui.Image> _sprites = <String, ui.Image>{};

  late SceneEventScheduler _events;

  final PlaybackClock _clock = PlaybackClock();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _events = SceneEventScheduler(layers: widget.scene.layers);
    _ticker = createTicker(_onTick)..start();
    unawaited(_loadSprites());
  }

  @override
  void didUpdateWidget(SceneLayersView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scene.id != widget.scene.id) {
      _sprites.clear();
      _events = SceneEventScheduler(layers: widget.scene.layers);
      _loading = true;
      unawaited(_loadSprites());
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frameTick.dispose();
    _sprites.clear();
    super.dispose();
  }

  Future<void> _loadSprites() async {
    final SpriteLoader loader = ref.read(spriteLoaderProvider);

    await Future.wait(
      widget.scene.layers.map((SceneLayerEntity layer) async {
        try {
          final ui.Image image = await loader.load(layer.spriteUrl);
          if (mounted) _sprites[layer.spriteUrl] = image;
        } on Object {
          // A sprite that will not load costs us that layer, not the scene.
        }
      }),
    );

    if (mounted) setState(() => _loading = false);
  }

  void _onTick(Duration elapsed) {
    _clock.tick(elapsed, isPlaying: _isPlaying);
    _events.update(elapsed);
    _frameTick.value++;
  }

  bool get _isPlaying =>
      ref.read(playerControllerProvider.select((state) => state.isPlaying));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SceneLayersPainter(
          scene: widget.scene,
          sprites: _sprites,
          events: _events,
          elapsed: () => _clock.sceneTime,
          playingElapsed: () => _clock.playingTime,
          driftPeriod: _driftPeriod,
          devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
          repaint: _frameTick,
        ),
      ),
    );
  }
}

class _SceneLayersPainter extends CustomPainter {
  _SceneLayersPainter({
    required this.scene,
    required this.sprites,
    required this.events,
    required this.elapsed,
    required this.playingElapsed,
    required this.driftPeriod,
    required this.devicePixelRatio,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final SceneEntity scene;
  final Map<String, ui.Image> sprites;
  final SceneEventScheduler events;
  final Duration Function() elapsed;
  final Duration Function() playingElapsed;
  final Duration driftPeriod;
  final double devicePixelRatio;

  static final Paint _pixelPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  @override
  void paint(Canvas canvas, Size size) {
    if (scene.layers.isEmpty) return;

    final double scale = _integerScaleFor(size);
    final double scaledWidth = scene.canvasWidth * scale;
    final double scaledHeight = scene.canvasHeight * scale;

    // Centre the canvas and let the overflow fall off the edges. Snapping to
    // whole device pixels keeps the grid from landing on a half pixel.
    final double originX = _snap((size.width - scaledWidth) / 2);
    final double originY = _snap((size.height - scaledHeight) / 2);

    final double drift = _drift();

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    for (final SceneLayerEntity layer in scene.layers) {
      final ui.Image? sprite = sprites[layer.spriteUrl];
      if (sprite == null) continue;

      _paintLayer(
        canvas: canvas,
        size: size,
        layer: layer,
        sprite: sprite,
        scale: scale,
        originX: originX,
        originY: originY,
        drift: drift,
      );
    }

    canvas.restore();
  }

  void _paintLayer({
    required Canvas canvas,
    required Size size,
    required SceneLayerEntity layer,
    required ui.Image sprite,
    required double scale,
    required double originX,
    required double originY,
    required double drift,
  }) {
    final double frameWidth = sprite.width / layer.frameCount;
    final double frameHeight = sprite.height.toDouble();
    final int frame = _frameIndexFor(layer);

    final Rect src = Rect.fromLTWH(
      frame * frameWidth,
      0,
      frameWidth,
      frameHeight,
    );

    // Nearer layers travel further with the camera; that difference is the
    // whole trick behind parallax.
    final double shift = drift * layer.parallax * scale;
    final double left = _snap(originX + layer.offsetX * scale + shift);
    final double top = _snap(originY + layer.offsetY * scale);
    final double width = frameWidth * scale;
    final double height = frameHeight * scale;

    if (!layer.tiles) {
      canvas.drawImageRect(
        sprite,
        src,
        Rect.fromLTWH(left, top, width, height),
        _pixelPaint,
      );
      return;
    }

    // Tiling layers cover the viewport, starting far enough back that the
    // drift never exposes an edge.
    for (double y = top - height; y < size.height + height; y += height) {
      for (double x = left - width; x < size.width + width; x += width) {
        canvas.drawImageRect(
          sprite,
          src,
          Rect.fromLTWH(_snap(x), _snap(y), width, height),
          _pixelPaint,
        );
      }
    }
  }

  /// Which frame of the strip is showing right now.
  int _frameIndexFor(SceneLayerEntity layer) {
    // Rare events keep their own schedule: resting on frame 0 between turns.
    if (layer.isEvent) return events.frameFor(layer, elapsed());

    return frameIndexAt(
      clock: layer.onlyWhilePlaying ? playingElapsed() : elapsed(),
      fps: layer.fps,
      frameCount: layer.frameCount,
    );
  }

  double _integerScaleFor(Size size) => sceneScaleFor(
    viewport: size,
    canvasWidth: scene.canvasWidth,
    canvasHeight: scene.canvasHeight,
  ).toDouble();

  /// One canvas pixel out and back, on a sine.
  double _drift() {
    final double period = driftPeriod.inMilliseconds.toDouble();
    final double phase = (elapsed().inMilliseconds % period) / period;

    return math.sin(phase * 2 * math.pi);
  }

  /// Rounds to a whole device pixel.
  double _snap(double value) =>
      (value * devicePixelRatio).roundToDouble() / devicePixelRatio;

  @override
  bool shouldRepaint(_SceneLayersPainter oldDelegate) =>
      oldDelegate.scene != scene || oldDelegate.sprites != sprites;
}
