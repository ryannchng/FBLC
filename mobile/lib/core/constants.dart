class AppConstants {
  AppConstants._();

  // Supabase
  // As we have Row Level Security enabled, these variables can be published safely
  static const String supabaseUrl = 'https://eudampfeempprbplgsfl.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_2BgyWzU1mTY5mzFWgqUAPA_X74zi-b1';

  // User roles
  static const String roleUser = 'user';
  static const String roleOwner = 'owner';

  // Pagination
  static const int pageSize = 20;

  // Map defaults (Canada)
  static const double defaultLatitude = 56.1304;
  static const double defaultLongitude = -106.3468;
  static const double defaultZoom = 12.0;
  static const double nearbyRadiusKm = 25.0;
}