/// The languages the app speaks (#140, #174), each named in its own
/// words: someone looking for their language finds it however the app
/// reads right now. Not translated, on purpose.
abstract final class AppLanguage {
  static const Map<String, String> names = <String, String>{
    'en': 'English',
    'de': 'Deutsch',
    'es': 'Español',
    'pt': 'Português',
    'fr': 'Français',
    'it': 'Italiano',
    'nl': 'Nederlands',
    'pl': 'Polski',
    'tr': 'Türkçe',
    'ru': 'Русский',
    'ja': '日本語',
    'ko': '한국어',
    'zh': '简体中文',
    'id': 'Bahasa Indonesia',
  };
}
