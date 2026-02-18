import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/screens/auth/login_screen.dart';
import 'supabase_client.dart';

// ---------------------------------------------------------------------------
// Route name constants — use these instead of raw strings
// ---------------------------------------------------------------------------
abstract class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const businessList = '/businesses';
  static const businessDetail = '/businesses/:id';
  static const writeReview = '/businesses/:id/review';
  static const profile = '/profile';
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------
class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    redirect: _guard,
    routes: [
      // Splash / loading
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const _SplashScreen(),
      ),

      // Auth
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) =>
            const LoginScreen(), // ← was _PlaceholderScreen
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) =>
            const _PlaceholderScreen(label: 'Register'),
      ),

      // Main app shell with bottom navigation
      ShellRoute(
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) =>
                const _PlaceholderScreen(label: 'Home'),
          ),
          GoRoute(
            path: AppRoutes.businessList,
            builder: (context, state) =>
                const _PlaceholderScreen(label: 'Businesses'),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => _PlaceholderScreen(
                  label: 'Business ${state.pathParameters['id']}',
                ),
                routes: [
                  GoRoute(
                    path: 'review',
                    builder: (context, state) => _PlaceholderScreen(
                      label: 'Write Review for ${state.pathParameters['id']}',
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) =>
                const _PlaceholderScreen(label: 'Profile'),
          ),
        ],
      ),
    ],
  );

  /// Redirect unauthenticated users to login and authenticated users away
  /// from auth screens.
  static String? _guard(BuildContext context, GoRouterState state) {
    final isLoggedIn = SupabaseClientProvider.isAuthenticated;
    final isOnAuthScreen =
        state.matchedLocation == AppRoutes.login ||
        state.matchedLocation == AppRoutes.register;
    final isOnSplash = state.matchedLocation == AppRoutes.splash;

    if (isOnSplash) {
      // Let the splash screen decide after checking session
      return null;
    }

    if (!isLoggedIn && !isOnAuthScreen) {
      return AppRoutes.login;
    }

    if (isLoggedIn && isOnAuthScreen) {
      return AppRoutes.home;
    }

    return null;
  }
}

// ---------------------------------------------------------------------------
// App shell with bottom navigation bar
// ---------------------------------------------------------------------------
class _AppShell extends StatelessWidget {
  const _AppShell({required this.child});

  final Widget child;

  static const _tabs = [
    (
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
      route: AppRoutes.home,
    ),
    (
      icon: Icons.store_outlined,
      activeIcon: Icons.store,
      label: 'Browse',
      route: AppRoutes.businessList,
    ),
    (
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profile',
      route: AppRoutes.profile,
    ),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouter.of(context).routeInformationProvider.value.uri;
    if (location.pathSegments.first == AppRoutes.businessList) return 1;
    if (location.pathSegments.first == AppRoutes.profile) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => context.go(_tabs[index].route),
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.activeIcon),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Splash screen — resolves auth state then redirects
// ---------------------------------------------------------------------------
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    // Small delay so the splash is visible for at least one frame
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (SupabaseClientProvider.isAuthenticated) {
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// ---------------------------------------------------------------------------
// Placeholder — replace with real screens as you build them
// ---------------------------------------------------------------------------
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(child: Text(label)),
    );
  }
}
