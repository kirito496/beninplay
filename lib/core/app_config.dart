class AppConfig {
  static const String apiBaseUrl = 'https://beninplay-api-production.up.railway.app';
  static const String supabaseUrl = 'https://cxyvvadkkbfmvbvprpnj.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4eXZ2YWRra2JmbXZidnBycG5qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIwNjgxNjYsImV4cCI6MjA5NzY0NDE2Nn0.qsCbRQ6fAnQzdg3iatEEC5daT5IbmMH6_pGaygWmZT4';
  static const String storageBucket = 'videos';
  // Agora (Live) — App ID public. Le certificat reste côté serveur (secret).
  static const String agoraAppId = '6b96a3b29c8346a5b14412352afffa91';
  static String get api => apiBaseUrl;

  // ── CDN Bunny.net (vidéos servies depuis Lagos, proche du Bénin) ──────────
  // Vide = désactivé (lecture directe Supabase). Dès que ta Pull Zone Bunny
  // est prête, mets ici son adresse : 'https://beninplay.b-cdn.net'
  static const String cdnBase = '';

  /// Fait passer une URL de fichier Supabase par le CDN (si configuré),
  /// sinon renvoie l'URL d'origine inchangée.
  static String cdn(String url) {
    if (cdnBase.isEmpty || url.isEmpty) return url;
    if (url.startsWith(supabaseUrl)) {
      return cdnBase + url.substring(supabaseUrl.length);
    }
    return url;
  }
}