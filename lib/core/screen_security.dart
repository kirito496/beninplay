import 'package:flutter/services.dart';

/// Protège l'écran contre les captures et l'enregistrement (Zone Dark).
///
/// Utilise le drapeau natif Android FLAG_SECURE : quand il est actif, toute
/// capture d'écran est bloquée et l'enregistrement d'écran ne montre qu'un
/// écran noir. (Sur iOS, l'appel est simplement ignoré.)
class ScreenSecurity {
  static const _channel = MethodChannel('beninplay/secure');

  /// Active la protection (à l'entrée de la Zone Dark).
  static Future<void> enable() async {
    try {
      await _channel.invokeMethod('enable');
    } catch (_) {
      // Plateforme non supportée (ex: iOS) — on ignore silencieusement.
    }
  }

  /// Désactive la protection (à la sortie de la Zone Dark).
  static Future<void> disable() async {
    try {
      await _channel.invokeMethod('disable');
    } catch (_) {}
  }
}
