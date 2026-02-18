import 'package:supabase_flutter/supabase_flutter.dart';

/// Convenience accessor so nothing outside of repositories
/// needs to import supabase_flutter directly.
class SupabaseClientProvider {
  SupabaseClientProvider._();

  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => Supabase.instance.client.auth;

  /// The currently authenticated user, or null if not signed in.
  static User? get currentUser => Supabase.instance.client.auth.currentUser;

  /// Whether a user is currently signed in.
  static bool get isAuthenticated => currentUser != null;

  /// Stream of auth state changes (sign-in, sign-out, token refresh, etc.).
  static Stream<AuthState> get authStateChanges =>
      Supabase.instance.client.auth.onAuthStateChange;
}
