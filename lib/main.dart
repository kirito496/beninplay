import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_config.dart';
import 'core/api_service.dart';
import 'core/app_prefs.dart';
import 'core/biometric.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/home/home_screen.dart';
import 'services/saved_videos.dart';
import 'services/seen_videos.dart';
import 'services/push_service.dart';
import 'shared/widgets/bp_logo.dart';

/// Observateur global des routes : permet aux écrans (ex: le fil vidéo) de
/// savoir quand un AUTRE écran s'ouvre par-dessus eux, pour mettre la vidéo en
/// pause (sinon le son continue en arrière-plan).
final RouteObserver<PageRoute<dynamic>> routeObserver = RouteObserver<PageRoute<dynamic>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  await SavedVideos.init(); // précharge les favoris (état des boutons 🔖)
  await SeenVideos.init(); // précharge les vidéos déjà vues (fil sans répétition)
  await AppPrefs.init(); // réglages (notifs, confidentialité, langue, verrou)
  await PushService.init(); // notifications push (best-effort, n'échoue jamais)
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const BeninPlayApp());
}

class BeninPlayApp extends StatelessWidget {
  const BeninPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeninPlay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      navigatorObservers: [routeObserver],
      home: const _SplashRouter(),
    );
  }
}

class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  bool _locked = false;

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final token = await ApiService.getToken();
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      // Verrou biométrique activé → on demande l'empreinte avant d'entrer.
      if (AppPrefs.biometricLock) {
        await _unlockThenHome();
      } else {
        _goHome();
      }
    } else {
      // Première ouverture → écran d'accueil (avantages + invitation), une seule
      // fois ; sinon directement la connexion.
      final firstTime = !AppPrefs.getBool('welcome_seen', false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => firstTime ? const WelcomeScreen() : const LoginScreen()),
      );
    }
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _unlockThenHome() async {
    final ok = await Biometric.confirm('Déverrouille BeninPlay');
    if (!mounted) return;
    if (ok) {
      _goHome();
    } else {
      setState(() => _locked = true); // affiche l'écran de déverrouillage
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        // Fond avec une lueur verte douce (fini le noir plat)
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.1,
            colors: [Color(0xFF07200F), Colors.black],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BpLogo(size: 104),
              const SizedBox(height: 22),
              const Text(
                'BeninPlay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Le divertissement béninois',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 44),
              if (_locked)
                ElevatedButton.icon(
                  onPressed: _unlockThenHome,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Déverrouiller'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                )
              else
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Color(0xFF00E676),
                    strokeWidth: 2.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
