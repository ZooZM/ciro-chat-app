/// Curated BCP-47 target languages offered by [TranslationToggleSheet]'s
/// language picker (T025) and used by `TranslationCubit.resolveTargetLanguage`
/// (FR-001) to validate the listener's device language.
const List<String> kSupportedTranslationLanguages = [
  'en',
  'ar',
  'fr',
  'es',
  'de',
  'it',
  'pt',
  'ru',
  'zh',
  'ja',
  'ko',
  'hi',
  'tr',
];

/// Display names for [kSupportedTranslationLanguages], keyed by language code.
const Map<String, String> kTranslationLanguageNames = {
  'en': 'English',
  'ar': 'العربية',
  'fr': 'Français',
  'es': 'Español',
  'de': 'Deutsch',
  'it': 'Italiano',
  'pt': 'Português',
  'ru': 'Русский',
  'zh': '中文',
  'ja': '日本語',
  'ko': '한국어',
  'hi': 'हिन्दी',
  'tr': 'Türkçe',
};
