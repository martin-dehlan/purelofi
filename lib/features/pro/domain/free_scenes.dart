import '../../player/domain/scene.entity.dart';

/// How many scenes are free. The rest are Pro (#16).
const int freeSceneCount = 2;

/// The scenes anyone can open: the first [freeSceneCount] by `sort_order`.
///
/// The one rule for what is free, kept in one place. Reordering the scenes
/// in Supabase is what changes which two they are.
Set<String> freeSceneIds(List<SceneEntity> scenes) {
  final List<SceneEntity> ordered = <SceneEntity>[...scenes]
    ..sort((SceneEntity a, SceneEntity b) {
      final int byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
    });

  return ordered.take(freeSceneCount).map((SceneEntity s) => s.id).toSet();
}

/// The scenes this listener cannot open yet. None when they have Pro, and
/// none when Pro cannot be bought in this build.
Set<String> lockedSceneIds(
  List<SceneEntity> scenes, {
  required bool isPro,
  required bool proAvailable,
}) {
  if (isPro || !proAvailable) return <String>{};

  final Set<String> free = freeSceneIds(scenes);

  return scenes
      .map((SceneEntity s) => s.id)
      .where((String id) => !free.contains(id))
      .toSet();
}
