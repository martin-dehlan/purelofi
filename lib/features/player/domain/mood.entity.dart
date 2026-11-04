import 'package:freezed_annotation/freezed_annotation.dart';

part 'mood.entity.freezed.dart';

/// A list of tracks PureLofi put together for a feeling: "Rainy evenings",
/// "Deep focus" (#141).
@freezed
abstract class MoodEntity with _$MoodEntity {
  const factory MoodEntity({
    required String id,
    required String slug,
    required String title,
    String? coverUrl,

    /// In the order the mood plays them.
    @Default(<String>[]) List<String> trackIds,
  }) = _MoodEntity;
}

/// Where the moods come from: Supabase, with the last copy on the device.
abstract class MoodRepository {
  Future<List<MoodEntity>> getMoods();
}
