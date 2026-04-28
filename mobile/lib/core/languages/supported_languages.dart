import 'dart:ui';

class SupportedLanguage {
  const SupportedLanguage({required this.code, required this.name});

  final String code;
  final String name;
}

const supportedLanguages = <SupportedLanguage>[
  SupportedLanguage(code: 'ar', name: 'Arabic (العربية)'),
  SupportedLanguage(code: 'bn', name: 'Bengali (বাংলা)'),
  SupportedLanguage(code: 'zh', name: 'Chinese (中文)'),
  SupportedLanguage(code: 'nl', name: 'Dutch'),
  SupportedLanguage(code: 'en', name: 'English'),
  SupportedLanguage(code: 'fr', name: 'French'),
  SupportedLanguage(code: 'de', name: 'German'),
  SupportedLanguage(code: 'hi', name: 'Hindi (हिन्दी)'),
  SupportedLanguage(code: 'id', name: 'Indonesian'),
  SupportedLanguage(code: 'it', name: 'Italian'),
  SupportedLanguage(code: 'ja', name: 'Japanese (日本語)'),
  SupportedLanguage(code: 'ko', name: 'Korean (한국어)'),
  SupportedLanguage(code: 'ms', name: 'Malay'),
  SupportedLanguage(code: 'fa', name: 'Persian (فارسی)'),
  SupportedLanguage(code: 'pl', name: 'Polish'),
  SupportedLanguage(code: 'pt', name: 'Portuguese'),
  SupportedLanguage(code: 'ru', name: 'Russian (Русский)'),
  SupportedLanguage(code: 'es', name: 'Spanish'),
  SupportedLanguage(code: 'sw', name: 'Swahili'),
  SupportedLanguage(code: 'ta', name: 'Tamil (தமிழ்)'),
  SupportedLanguage(code: 'te', name: 'Telugu (తెలుగు)'),
  SupportedLanguage(code: 'th', name: 'Thai (ภาษาไทย)'),
  SupportedLanguage(code: 'tr', name: 'Turkish'),
  SupportedLanguage(code: 'uk', name: 'Ukrainian'),
  SupportedLanguage(code: 'ur', name: 'Urdu (اردو)'),
  SupportedLanguage(code: 'vi', name: 'Vietnamese'),
];

String defaultSupportedLanguageCode({Locale? locale}) {
  final languageCode = (locale ?? PlatformDispatcher.instance.locale)
      .languageCode
      .toLowerCase();
  final isSupported = supportedLanguages.any(
    (language) => language.code == languageCode,
  );
  return isSupported ? languageCode : 'en';
}
