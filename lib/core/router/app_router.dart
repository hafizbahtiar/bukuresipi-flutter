import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/places/presentation/pages/pin_picker_page.dart';
import '../../features/places/presentation/pages/place_detail_page.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/pages/account_page.dart';
import '../../features/auth/presentation/pages/change_password_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/owner/presentation/pages/owner_page.dart';
import '../../features/owner/presentation/pages/owner_shares_page.dart';
import '../../features/owner/presentation/pages/owner_users_page.dart';
import '../../features/shares/presentation/share_page.dart';
import '../network/update_gate.dart';
import '../widgets/system_pages.dart';

/// Screens anyone may open, signed in or not. Email links (App Links) land on /auth/* and /en/auth/*.
bool isPublic(String path) =>
    const {'/login', '/register', '/forgot'}.contains(path) ||
    path.startsWith('/auth/') ||
    path.startsWith('/en/auth/');

/// Where to send the user, or null to stay. Pure, so it is unit-tested without widgets.
String? redirectFor(String path, AuthController auth, UpdateGate update) {
  if (update.required) return path == '/update' ? null : '/update';
  switch (auth.status) {
    case AuthStatus.unknown:
      return isPublic(path) || path == '/splash' ? null : '/splash';
    case AuthStatus.signedOut:
      return isPublic(path) ? null : '/login';
    case AuthStatus.signedIn:
      if (const {'/login', '/register', '/splash', '/update'}.contains(path)) {
        return '/';
      }
      if (path.startsWith('/owner') && !(auth.user?.isOwner ?? false)) {
        return '/';
      }
      return null;
  }
}

GoRouter buildRouter(AuthController auth, UpdateGate update) {
  // Website paths for email links, in both languages: /auth/reset and /en/auth/reset open the same screen.
  List<GoRoute> linkRoutes(String prefix) => [
    GoRoute(
      path: '$prefix/auth/verify',
      builder: (_, s) => VerifyEmailPage(token: s.uri.queryParameters['token']),
    ),
    GoRoute(
      path: '$prefix/auth/reset',
      builder: (_, s) =>
          ResetPasswordPage(token: s.uri.queryParameters['token']),
    ),
    GoRoute(
      path: '$prefix/auth/forgot',
      builder: (_, _) => const ForgotPasswordPage(),
    ),
  ];

  return GoRouter(
    initialLocation: '/',
    refreshListenable: Listenable.merge([auth, update]),
    redirect: (_, state) => redirectFor(state.uri.path, auth, update),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/update', builder: (_, _) => const UpdateRequiredPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/forgot', builder: (_, _) => const ForgotPasswordPage()),
      ...linkRoutes(''),
      ...linkRoutes('/en'),
      GoRoute(path: '/account', builder: (_, _) => const AccountPage()),
      // Top level, not nested under /account: Account is also a home tab, so pushing this must add one page only.
      GoRoute(
        path: '/account/password',
        builder: (_, _) => const ChangePasswordPage(),
      ),
      GoRoute(path: '/share', builder: (_, _) => const SharePage()),
      GoRoute(
        path: '/places/:id',
        builder: (_, state) => PlaceDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/places/:id/pin/:branchId',
        builder: (_, state) => PinPickerPage(
          placeId: state.pathParameters['id']!,
          branchId: state.pathParameters['branchId']!,
        ),
      ),
      GoRoute(
        path: '/owner',
        builder: (_, _) => const OwnerPage(),
        routes: [
          GoRoute(path: 'users', builder: (_, _) => const OwnerUsersPage()),
          GoRoute(path: 'shares', builder: (_, _) => const OwnerSharesPage()),
        ],
      ),
    ],
  );
}
