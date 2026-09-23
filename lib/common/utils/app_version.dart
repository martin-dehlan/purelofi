/// What the app calls itself in the menu.
///
/// A constant rather than a `package_info_plus` lookup: the number is set in
/// `pubspec.yaml` and read once, and an async call to the platform for a
/// string that never changes is a lot of machinery for a footer. Keep it in
/// step with `pubspec.yaml` when the version is bumped on a store upload
/// (`docs/11`).
const String appVersion = '0.1.0';
