import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/services/auth_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/background_monitor_service.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge support for Android 15+ (API 35/36)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  // Initialize background service & persistent settings
  try {
    await SettingsService().init();
    BackgroundMonitorService.init();
  } catch (e) {
    debugPrint('Service init notice: $e');
  }

  runApp(const ProviderScope(child: IbnikApp()));
}

class IbnikApp extends StatelessWidget {
  const IbnikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MonitorSettings>(
      valueListenable: SettingsService().settingsNotifier,
      builder: (context, settings, _) {
        final themeData = AppTheme.getThemeData(settings.appThemeMode);
        return MaterialApp(
          title: 'Ibnik',
          debugShowCheckedModeBanner: false,
          theme: themeData,
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    if (!authService.isFirebaseAvailable) {
      // If Firebase is not configured yet, allow user directly into HomeScreen with Local P2P
      return const HomeScreen();
    }
    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
