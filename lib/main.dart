import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/login_screen.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bgBase,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Block on the MongoDB handshake BEFORE runApp() so the first frame
  // and any auto-subscribing streams (e.g. HomeScreen.watchReports) see
  // a verified-open connection instead of racing against init. If the
  // handshake fails, connect() has already logged the exact underlying
  // exception (SocketException / auth failure / DNS error) — we launch
  // anyway so the user can still log in, and the polling loop will
  // keep retrying with backoff.
  print('[BOOT] Connecting to MongoDB before runApp()…');
  try {
    await DatabaseService.instance.connect();
    print('[BOOT] MongoDB connection verified — launching app');
  } catch (e) {
    print('[BOOT] MongoDB connect failed — launching app anyway, '
        'watchReports will retry on a 5s backoff: $e');
  }

  runApp(const FixMyStreetApp());
}

class FixMyStreetApp extends StatelessWidget {
  const FixMyStreetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FixMyStreet',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const LoginScreen(),
    );
  }
}
