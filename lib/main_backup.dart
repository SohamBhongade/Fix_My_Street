import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/login_screen.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Surface every rendering / framework error to the console. Without this,
  // a silent paint failure (e.g. emulator GPU choking on a saveLayer) shows
  // up as a black screen with no diagnostic — the explicit print mirrors the
  // exception into stderr where adb logcat / `flutter run` can catch it.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // ignore: avoid_print
    print('[FLUTTER_ERROR] ${details.exceptionAsString()}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    // ignore: avoid_print
    print('[PLATFORM_ERROR] $error\n$stack');
    return true;
  };

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bgBase,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Fire the widget tree immediately so the engine has a fully-sized surface
  // to paint on the very first frame. The root widget owns its own boot
  // lifecycle via setState (see _FixMyStreetAppState).
  runApp(const FixMyStreetApp());
}

class FixMyStreetApp extends StatefulWidget {
  const FixMyStreetApp({super.key});

  @override
  State<FixMyStreetApp> createState() => _FixMyStreetAppState();
}

class _FixMyStreetAppState extends State<FixMyStreetApp> {
  /// Explicit state flag — flips to true once the MongoDB warm-up resolves
  /// (success or handled failure). Using a plain bool + setState rather than
  /// a FutureBuilder so the rebuild is unambiguously triggered by our own
  /// code and never depends on the framework re-subscribing to a Future.
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    // ignore: avoid_print
    print('[BOOT] _FixMyStreetAppState.initState — kicking off warm-up');
    _warmConnect();
  }

  /// Background MongoDB handshake. Errors are caught and logged — the boot
  /// gate flips open either way so the user can still reach the login form
  /// when Atlas is unreachable. Every downstream callsite re-enters
  /// `connect()` via `DatabaseService._ensureConnected`, so the cluster
  /// heals itself the moment the network comes back.
  Future<void> _warmConnect() async {
    // ignore: avoid_print
    print('[BOOT] Warming MongoDB connection in background…');
    try {
      await DatabaseService.instance.connect();
      // ignore: avoid_print
      print('[BOOT] MongoDB connection verified');
    } catch (e) {
      // ignore: avoid_print
      print('[BOOT] MongoDB connect failed — watchReports will retry: $e');
    }
    if (!mounted) return;
    // Explicit setState so Flutter unambiguously marks this StatefulWidget
    // dirty and schedules a rebuild → the build() below swaps from
    // _BootSplash to LoginScreen on the next frame.
    setState(() {
      // ignore: avoid_print
      print('[BOOT] Boot gate opening — rebuilding into LoginScreen');
      _booted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Both branches return a fully-constrained Scaffold inside MaterialApp,
    // so the renderer always sees a concrete, sized surface — never an
    // empty Container() or unsized SizedBox() (which is the shape that
    // produces the Android "FlutterRenderer: width is zero" log).
    return MaterialApp(
      title: 'FixMyStreet',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: _booted ? const LoginScreen() : const _BootSplash(),
    );
  }
}

/// Boot-time splash. Deliberately bold (large spinner + brand label + tagline)
/// so it's visually unmistakable on the emulator — if the screen still looks
/// blank, the engine isn't painting the Dart tree, and we know to look at the
/// Android side (launch theme / surface attach) rather than the widget tree.
class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  color: AppColors.olive,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'FixMyStreet',
                style: AppText.title.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.olive,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Connecting to the civic dashboard…',
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
