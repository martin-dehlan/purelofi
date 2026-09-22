import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/widgets/error_state.widget.dart';
import '../../../../common/widgets/loading_state.widget.dart';
import '../../controller/controls_visibility.controller.dart';
import '../../controller/scene_touch.controller.dart';
import '../../controller/player.controller.dart';
import '../../controller/player.provider.dart';
import '../../data/sprite_loader.service.dart';
import '../../domain/playback_clock.dart';
import '../../domain/scene.entity.dart';
import '../../domain/scene_event.scheduler.dart';
import '../../domain/scene_layer.entity.dart';

/// The smallest whole-number scale, in DEVICE pixels, that still covers
/// [viewport].
///
/// Device pixels, not logical points, and that distinction decides whether
/// the scene is watchable. On a 3x screen a 320-wide canvas only has the
/// choices 1x and 2x in logical points — 2x overshoots a 402pt viewport by
/// more than a third, so most of the art falls off the edges. Counting in
/// device pixels gives 4x, 5x, 6x instead: still exact whole pixels, but
/// fine enough steps to land close to the viewport.
///
/// Whole numbers throughout: a fractional scale resamples the art, which is
/// exactly what makes pixel art look soft inside a video.
int sceneScaleFor({
  required Size viewport,
  required int canvasWidth,
  required int canvasHeight,
  double devicePixelRatio = 1,
}) {
  if (canvasWidth <= 0 || canvasHeight <= 0) return 1;
  if (devicePixelRatio <= 0) return 1;

  final int byWidth = (viewport.width * devicePixelRatio / canvasWidth).ceil();
  final int byHeight = (viewport.height * devicePixelRatio / canvasHeight)
      .ceil();

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

/// How far a `hide_when_paused` layer has faded in, from 0 to 1.
///
/// A lamp that snaps on reads as a bug; one that takes a moment reads as a
/// lamp. [duration] is how long the full fade takes.
double stepFade(
  double current, {
  required bool isPlaying,
  required Duration delta,
  required Duration duration,
}) {
  if (duration <= Duration.zero) return isPlaying ? 1 : 0;

  final double step = delta.inMicroseconds / duration.inMicroseconds;
  final double target = isPlaying ? 1 : 0;

  if (step <= 0) return current.clamp(0, 1);

  final double moved = current + (target > current ? step : -step);

  return (target > current
          ? (moved > target ? target : moved)
          : (moved < target ? target : moved))
      .clamp(0, 1)
      .toDouble();
}

/// The canvas-space rectangle [layer] occupies, for hit testing a tap.
Rect layerBounds(SceneLayerEntity layer, {required Size frameSize}) =>
    Rect.fromLTWH(
      layer.offsetX.toDouble(),
      layer.offsetY.toDouble(),
      frameSize.width,
      frameSize.height,
    );

/// How opaque [layer] should be drawn, given how far the lamp has faded.
double layerOpacity(SceneLayerEntity layer, {required double fade}) =>
    layer.hideWhenPaused ? fade : 1;

/// Which frame of [layer]'s strip belongs on screen right now.
///
/// Anything that waits for a cue — a rare event, a tap, a new track — is the
/// scheduler's business: it holds the idle loop until the cue comes and plays
/// the reaction once. Left to the plain clock, a layer like that would run
/// its reaction over and over on its own. Everything else simply follows its
/// clock, which for a `only_while_playing` layer stops with the music.
int frameForLayer(
  SceneLayerEntity layer, {
  required SceneEventScheduler events,
  required Duration elapsed,
  required Duration playingElapsed,
}) {
  if (layer.isTriggered) return events.frameFor(layer, elapsed);

  return frameIndexAt(
    clock: layer.onlyWhilePlaying ? playingElapsed : elapsed,
    fps: layer.fps,
    frameCount: layer.frameCount,
  );
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

  /// How long the lamp takes to come up or go down.
  static const Duration _lampFade = Duration(milliseconds: 2200);

  double _fade = 0;
  Duration _lastFadeTick = Duration.zero;

  bool _loading = true;

  /// What went wrong while fetching the sprites, if every one of them failed.
  ///
  /// A scene missing one layer is still a scene, so a single failure is
  /// swallowed on purpose. A scene missing all of them is a black screen,
  /// and a black screen must say something.
  Object? _spriteError;

  /// The track the scene last reacted to, so a new one can be spotted.
  String? _lastTrackId;

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
    Object? lastFailure;

    await Future.wait(
      widget.scene.layers.map((SceneLayerEntity layer) async {
        try {
          final ui.Image image = await loader.load(layer.spriteUrl);
          if (mounted) _sprites[layer.spriteUrl] = image;
        } on Object catch (error) {
          // A sprite that will not load costs us that layer, not the scene —
          // unless it costs us every layer, which is the case below.
          lastFailure = error;
        }
      }),
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
      _spriteError = _sprites.isEmpty ? lastFailure : null;
    });
  }

  void _onTick(Duration elapsed) {
    final Duration delta = elapsed - _lastFadeTick;
    _lastFadeTick = elapsed;
    if (delta > Duration.zero) {
      _fade = stepFade(
        _fade,
        isPlaying: _isPlaying,
        delta: delta,
        duration: _lampFade,
      );
    }

    _clock.tick(elapsed, isPlaying: _isPlaying);
    _events.update(elapsed);
    _frameTick.value++;
  }

  bool get _isPlaying =>
      ref.read(playerControllerProvider.select((state) => state.isPlaying));

  /// Wakes the layers that answer to the music when a new track starts.
  void _reactToTrackChange() {
    final String? trackId = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack?.id),
    );
    if (trackId == null || trackId == _lastTrackId) return;

    final bool first = _lastTrackId == null;
    _lastTrackId = trackId;
    // The very first track is the app starting, not a skip.
    if (first) return;

    for (final SceneLayerEntity layer in widget.scene.layers) {
      if (layer.onTrackChange) {
        _events.trigger(layer.id, _clock.sceneTime);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _reactToTrackChange();

    if (_loading) return const LoadingState();

    final Object? error = _spriteError;
    if (error != null) {
      return ErrorState(
        error: error,
        onRetry: () {
          setState(() {
            _loading = true;
            _spriteError = null;
          });
          unawaited(_loadSprites());
        },
      );
    }

    return Listener(
      // A Listener rather than a GestureDetector: the chrome's own tap
      // handler still gets the event, so touching the cat also wakes the
      // controls.
      onPointerDown: _onPointerDown,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: CustomPaint(
          size: Size.infinite,
          painter: _SceneLayersPainter(
            scene: widget.scene,
            sprites: _sprites,
            events: _events,
            fade: () => _fade,
            elapsed: () => _clock.sceneTime,
            playingElapsed: () => _clock.playingTime,
            driftPeriod: _driftPeriod,
            devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
            repaint: _frameTick,
          ),
        ),
      ),
    );
  }

  /// Wakes whatever the listener touched, if anything.
  ///
  /// Only while the chrome is hidden: with the transport on screen a tap
  /// belongs to the interface, and poking the scene would fight it.
  void _onPointerDown(PointerDownEvent event) {
    if (ref.read(controlsVisibilityControllerProvider)) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final Size size = box.size;
    final double dpr = MediaQuery.of(context).devicePixelRatio;
    final double scale =
        sceneScaleFor(
          viewport: size,
          canvasWidth: widget.scene.canvasWidth,
          canvasHeight: widget.scene.canvasHeight,
          devicePixelRatio: dpr,
        ) /
        dpr;

    // Back from the screen into the canvas the art was drawn on.
    final Offset local = box.globalToLocal(event.position);
    final double originX = (size.width - widget.scene.canvasWidth * scale) / 2;
    final double originY =
        (size.height - widget.scene.canvasHeight * scale) / 2;
    final Offset canvasPoint = Offset(
      (local.dx - originX) / scale,
      (local.dy - originY) / scale,
    );

    // Front to back, so the nearest thing wins.
    for (final SceneLayerEntity layer in widget.scene.layers.reversed) {
      if (!layer.tappable) continue;

      final ui.Image? sprite = _sprites[layer.spriteUrl];
      if (sprite == null) continue;

      final Rect bounds = layerBounds(
        layer,
        frameSize: Size(
          sprite.width / layer.frameCount,
          sprite.height.toDouble(),
        ),
      );
      if (bounds.contains(canvasPoint)) {
        if (_events.trigger(layer.id, _clock.sceneTime)) {
          // The chrome must not reappear: the tap was for the cat, not for
          // the interface.
          ref.read(sceneTouchControllerProvider.notifier).consume();
        }
        return;
      }
    }
  }
}

class _SceneLayersPainter extends CustomPainter {
  _SceneLayersPainter({
    required this.scene,
    required this.sprites,
    required this.events,
    required this.fade,
    required this.elapsed,
    required this.playingElapsed,
    required this.driftPeriod,
    required this.devicePixelRatio,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final SceneEntity scene;
  final Map<String, ui.Image> sprites;
  final SceneEventScheduler events;
  final double Function() fade;
  final Duration Function() elapsed;
  final Duration Function() playingElapsed;
  final Duration driftPeriod;
  final double devicePixelRatio;

  static final Paint _pixelPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  /// Same nearest-neighbour paint, dimmed — used while the lamp fades.
  static Paint _fadedPaint(double opacity) => Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false
    ..colorFilter = ColorFilter.mode(
      Color.fromRGBO(255, 255, 255, opacity),
      BlendMode.modulate,
    );

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

    final double lampFade = fade();

    for (final SceneLayerEntity layer in scene.layers) {
      final double opacity = layerOpacity(layer, fade: lampFade);
      if (opacity <= 0.01) continue;

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
        opacity: opacity,
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
    required double opacity,
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

    final Paint paint = opacity >= 1 ? _pixelPaint : _fadedPaint(opacity);

    if (!layer.tiles) {
      canvas.drawImageRect(
        sprite,
        src,
        Rect.fromLTWH(left, top, width, height),
        paint,
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
          paint,
        );
      }
    }
  }

  /// Which frame of the strip is showing right now.
  int _frameIndexFor(SceneLayerEntity layer) => frameForLayer(
    layer,
    events: events,
    elapsed: elapsed(),
    playingElapsed: playingElapsed(),
  );

  /// The device-pixel scale expressed in logical points, which is what the
  /// canvas draws in.
  double _integerScaleFor(Size size) =>
      sceneScaleFor(
        viewport: size,
        canvasWidth: scene.canvasWidth,
        canvasHeight: scene.canvasHeight,
        devicePixelRatio: devicePixelRatio,
      ) /
      devicePixelRatio;

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
