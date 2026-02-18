import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthRepository {
  // -------------------------------------------------------------------------
  // Sign in
  // -------------------------------------------------------------------------
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await SupabaseClientProvider.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.user == null) {
        throw const AuthException('Sign in failed. Please try again.');
      }
      return response;
    } on AuthApiException catch (e) {
      throw AuthException(_mapAuthError(e.message));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('An unexpected error occurred. Please try again.');
    }
  }

  // -------------------------------------------------------------------------
  // Register
  // -------------------------------------------------------------------------
  Future<AuthResponse> registerWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      // Check username is unique before creating auth user
      final existing = await SupabaseClientProvider.client
          .from('users')
          .select('id')
          .eq('username', username.trim())
          .maybeSingle();

      if (existing != null) {
        throw const AuthException('That username is already taken.');
      }

      final response = await SupabaseClientProvider.auth.signUp(
        email: email.trim(),
        password: password,
      );

      if (response.user == null) {
        throw const AuthException('Registration failed. Please try again.');
      }

      // Create the public profile row that mirrors auth.users
      await SupabaseClientProvider.client.from('users').insert({
        'id': response.user!.id,
        'username': username.trim(),
      });

      return response;
    } on AuthApiException catch (e) {
      throw AuthException(_mapAuthError(e.message));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('An unexpected error occurred. Please try again.');
    }
  }

  // -------------------------------------------------------------------------
  // Password reset
  // -------------------------------------------------------------------------
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await SupabaseClientProvider.auth.resetPasswordForEmail(email.trim());
    } on AuthApiException catch (e) {
      throw AuthException(_mapAuthError(e.message));
    } catch (_) {
      throw const AuthException('Could not send reset email. Please try again.');
    }
  }

  // -------------------------------------------------------------------------
  // Sign out
  // -------------------------------------------------------------------------
  Future<void> signOut() async {
    await SupabaseClientProvider.auth.signOut();
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------
  String _mapAuthError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid email or password')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please verify your email address before signing in.';
    }
    if (msg.contains('user already registered')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('password should be at least')) {
      return 'Password must be at least 6 characters.';
    }
    if (msg.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    return raw;
  }
}