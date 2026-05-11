/// =====================================================================
/// FixMyStreet AI — Configuration
/// =====================================================================
/// SECURITY NOTE
/// -------------
/// Do NOT commit real credentials to source control.
/// Replace the placeholder values below with your real keys locally, and
/// add `lib/config.dart` to your `.gitignore`.
///
/// HOW TO SET UP
/// -------------
/// 1. Obtain a Gemini API key from https://aistudio.google.com/app/apikey
/// 2. Create a MongoDB Atlas cluster and a database user. Copy the
///    SRV connection string from Atlas → Connect → Drivers.
/// 3. Replace the placeholders below.
/// 4. For production, prefer `--dart-define` injection:
///        flutter run --dart-define=GEMINI_API_KEY=xxx \
///                    --dart-define=MONGO_URI=mongodb+srv://...
/// =====================================================================
library;

class AppConfig {
  /// Gemini API key. Prefer compile-time injection via --dart-define.
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'YOUR_GEMINI_API_KEY_HERE',
  );

  /// Gemini model id — vision-capable.
  static const String geminiModel = 'gemini-2.0-flash';

  /// MongoDB Atlas connection string.
  /// IMPORTANT: stored as a raw string (r'...') so special characters in
  /// the password (e.g. `@`, `$`, `&`) are not interpreted by Dart.
  static const String mongoUri = String.fromEnvironment(
    'MONGO_URI',
    defaultValue:
        r'mongodb+srv://sohambhongade15:Tabpro123@cluster0.xxxxx.mongodb.net/fixmystreet?retryWrites=true&w=majority',
  );

  /// Mongo collection where reports are persisted.
  static const String reportsCollection = 'reports';

  /// City scope — used to anchor reverse-geocoded location strings.
  static const String defaultCity = 'Ras Al Khaimah, UAE';
}
