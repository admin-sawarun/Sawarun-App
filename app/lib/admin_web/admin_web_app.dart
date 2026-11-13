import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth/access_denied_page.dart';
import 'auth/admin_session.dart';
import 'auth/login_page.dart';
import 'pages/activity_page.dart';
import 'pages/affiliate_page.dart';
import 'pages/analyses_page.dart';
import 'pages/brands_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/posts_page.dart';
import 'pages/products_page.dart';
import 'pages/reports_page.dart';
import 'pages/settings_page.dart';
import 'pages/team_page.dart';
import 'pages/tuning_page.dart';
import 'pages/users_page.dart';
import 'shell/admin_shell.dart';
import 'widgets/common.dart';

/// Root of the web admin dashboard (entry: lib/main_admin.dart).
class AdminWebApp extends ConsumerStatefulWidget {
  const AdminWebApp({super.key});

  @override
  ConsumerState<AdminWebApp> createState() => _AdminWebAppState();
}

class _AdminWebAppState extends ConsumerState<AdminWebApp> {
  late final GoRouter _router = _buildRouter(ref.read(adminSessionProvider));

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Savarun Admin',
      debugShowCheckedModeBanner: false,
      theme: buildAdminTheme(),
      routerConfig: _router,
    );
  }
}

GoRouter _buildRouter(AdminSession session) {
  const authPages = {'/splash', '/login', '/denied'};
  String? intended; // deep link to restore after the claim check

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: session,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      switch (session.status) {
        case SessionStatus.loading:
          if (!authPages.contains(loc)) intended = state.uri.toString();
          return loc == '/splash' ? null : '/splash';
        case SessionStatus.signedOut:
          if (!authPages.contains(loc)) intended = state.uri.toString();
          return loc == '/login' ? null : '/login';
        case SessionStatus.denied:
          return loc == '/denied' ? null : '/denied';
        case SessionStatus.admin:
          if (authPages.contains(loc)) {
            final to = intended ?? '/dashboard';
            intended = null;
            return to;
          }
          return null;
      }
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/dashboard'),
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
      GoRoute(path: '/login', builder: (_, _) => const AdminLoginPage()),
      GoRoute(path: '/denied', builder: (_, _) => const AccessDeniedPage()),
      ShellRoute(
        builder: (context, state, child) =>
            AdminShell(location: state.matchedLocation, child: child),
        routes: [
          for (final item in adminNavItems)
            GoRoute(
              path: item.path,
              pageBuilder: (_, _) =>
                  NoTransitionPage(child: _pageFor(item.path)),
            ),
        ],
      ),
    ],
  );
}

Widget _pageFor(String path) => switch (path) {
      '/users' => const UsersPage(),
      '/brands' => const BrandsPage(),
      '/products' => const ProductsPage(),
      '/reports' => const ReportsPage(),
      '/tuning' => const TuningPage(),
      '/posts' => const PostsPage(),
      '/analyses' => const AnalysesPage(),
      '/affiliate' => const AffiliatePage(),
      '/team' => const TeamPage(),
      '/activity' => const ActivityPage(),
      '/settings' => const SettingsPage(),
      _ => const DashboardPage(),
    };

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(height: 16),
            Text('Checking access…',
                style: TextStyle(color: AdminPalette.muted)),
          ],
        ),
      ),
    );
  }
}

ThemeData buildAdminTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AdminPalette.accent,
    primary: AdminPalette.accent,
    surface: AdminPalette.surface,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AdminPalette.background,
    visualDensity: VisualDensity.standard,
  );
  final radius = BorderRadius.circular(10);
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AdminPalette.ink,
      displayColor: AdminPalette.ink,
    ),
    dividerTheme: const DividerThemeData(
        color: AdminPalette.border, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        foregroundColor: AdminPalette.ink,
        side: const BorderSide(color: AdminPalette.border),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AdminPalette.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AdminPalette.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AdminPalette.accent, width: 1.4)),
    ),
    dataTableTheme: DataTableThemeData(
      headingTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AdminPalette.muted,
          letterSpacing: 0.3),
      dataTextStyle: const TextStyle(fontSize: 13.5, color: AdminPalette.ink),
      headingRowColor: WidgetStateProperty.all(const Color(0xFFFAFAFC)),
      dividerThickness: 1,
      horizontalMargin: 20,
      columnSpacing: 28,
    ),
    chipTheme: base.chipTheme.copyWith(
      side: const BorderSide(color: AdminPalette.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 400)),
  );
}
