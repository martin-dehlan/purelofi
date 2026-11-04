import 'package:freezed_annotation/freezed_annotation.dart';

part 'ambient_loop.freezed.dart';

/// One of the room's sounds as the audio service plays it (#136): which
/// file, and how loud in the listener's mix, 0 to 1.
@freezed
abstract class AmbientLoop with _$AmbientLoop {
  const factory AmbientLoop({
    required String id,
    required String url,
    required double level,
  }) = _AmbientLoop;
}
