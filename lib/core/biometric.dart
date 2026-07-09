import 'package:local_auth/local_auth.dart';

/// Verrou biométrique (empreinte digitale / visage) pour les actions sensibles
/// comme le retrait d'argent.
class Biometric {
  static final _auth = LocalAuthentication();

  /// Demande l'empreinte. Retourne true si validé OU si l'appareil n'a pas de
  /// biométrie configurée (on ne bloque pas un utilisateur sans capteur).
  static Future<bool> confirm(String reason) async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!supported || !canCheck) return true; // pas de biométrie → on n'empêche pas
      final available = await _auth.getAvailableBiometrics();
      if (available.isEmpty) return true;
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      // En cas d'erreur du capteur, on ne bloque pas l'utilisateur légitime.
      return true;
    }
  }
}
