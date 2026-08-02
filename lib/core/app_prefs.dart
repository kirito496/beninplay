import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Réglages de l'app persistés sur le téléphone (notifications, confidentialité,
/// sécurité, langue). Simple et fiable — aucun serveur requis.
class AppPrefs {
  AppPrefs._();

  static SharedPreferences? _p;

  static Future<void> init() async {
    _p ??= await SharedPreferences.getInstance();
    language.value = getString('language', 'fr');
  }

  static bool getBool(String k, bool def) => _p?.getBool(k) ?? def;
  static Future<void> setBool(String k, bool v) async => _p?.setBool(k, v);
  static String getString(String k, String def) => _p?.getString(k) ?? def;
  static Future<void> setString(String k, String v) async => _p?.setString(k, v);

  // ── Langue (avec notifier pour rafraîchir l'étiquette dans les réglages) ──
  static final ValueNotifier<String> language = ValueNotifier<String>('fr');
  static Future<void> setLanguage(String code) async {
    await setString('language', code);
    language.value = code;
  }

  static String labelFor(String code) {
    switch (code) {
      case 'en': return 'English';
      case 'fon': return 'Fɔngbè';
      case 'yo': return 'Yorùbá';
      default: return 'Français';
    }
  }

  // ── Sécurité ──
  static bool get biometricLock => getBool('biometricLock', false);
  static Future<void> setBiometricLock(bool v) => setBool('biometricLock', v);

  // Pré-chargement de vidéos en arrière-plan (appli fermée). Activé par défaut,
  // données mobiles comprises.
  static bool get backgroundPrefetch => getBool('backgroundPrefetch', true);
  static Future<void> setBackgroundPrefetch(bool v) => setBool('backgroundPrefetch', v);
}
