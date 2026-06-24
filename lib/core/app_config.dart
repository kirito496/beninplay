class AppConfig {
  static const String apiBaseUrl = 'https://beninplay-api-production.up.railway.app';
  static const String supabaseUrl = 'https://cxyvvadkkbfmvbvprpnj.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4eXZ2YWRra2JmbXZidnBycG5qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIwNjgxNjYsImV4cCI6MjA5NzY0NDE2Nn0.qsCbRQ6fAnQzdg3iatEEC5daT5IbmMH6_pGaygWmZT4';
  static const String storageBucket = 'videos';
  static String get api => apiBaseUrl;
}