import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../core/api_service.dart';

/// Notifications push (Firebase Cloud Messaging).
///
/// Tout est enveloppé dans des try/catch : si Firebase n'est pas configuré ou
/// échoue, l'application continue de fonctionner normalement (best-effort).
class PushService {
  static bool _ready = false;

  /// À appeler UNE fois au démarrage (dans main), avant runApp de préférence.
  /// Initialise Firebase, demande l'autorisation et écoute les messages.
  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _ready = true;

      // Autorisation (iOS + Android 13+).
      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);

      // Message reçu quand l'appli est FERMÉE / en arrière-plan.
      FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

      // Le jeton change parfois → on le renvoie au serveur.
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        ApiService.registerPushToken(t);
      });
    } catch (_) {
      _ready = false; // Firebase absent/non configuré : on ignore.
    }
  }

  /// À appeler quand l'utilisateur est CONNECTÉ (ex: à l'ouverture de l'accueil).
  /// Récupère le jeton FCM et l'enregistre côté serveur.
  static Future<void> registerToken() async {
    if (!_ready) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await ApiService.registerPushToken(token);
    } catch (_) { /* ignoré */ }
  }
}

/// Handler d'arrière-plan (isolé séparé). Le système affiche la notification
/// automatiquement ; on n'a rien à faire ici.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {}
