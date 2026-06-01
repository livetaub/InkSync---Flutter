/// InkSync App Configuration
/// Contains all environment variables and app constants
library;

class AppConfig {
  // Firebase Configuration (from environment or hardcoded for now)
  static const String firebaseApiKey =
      'AIzaSyCrBwoasjAIxn0XY7Fd83N-ypC4DddaS-0';
  static const String firebaseAuthDomain = 'tintnotes.firebaseapp.com';
  static const String firebaseProjectId = 'tintnotes';
  static const String firebaseStorageBucket = 'tintnotes.firebasestorage.app';
  static const String firebaseMessagingSenderId = '864468840662';
  static const String firebaseAppId =
      '1:864468840662:web:976da670d200f7b6929977';

  // App Info
  static const String appName = 'InkSync';
  static const String appVersion = '2.0.0';
}
