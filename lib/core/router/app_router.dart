import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import '../../features/places/presentation/pages/pin_picker_page.dart';
import '../../features/places/presentation/pages/places_map_page.dart';
import '../../features/places/presentation/pages/place_detail_page.dart';
import '../../features/places/presentation/pages/reviews_page.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/achievements/presentation/pages/badges_page.dart';
import '../../features/auth/presentation/pages/usage_page.dart';
import '../../features/auth/presentation/pages/settings_page.dart';
import '../../features/auth/presentation/pages/account_page.dart';
import '../../features/auth/presentation/pages/change_email_page.dart';
import '../../features/auth/presentation/pages/passkeys_page.dart';
import '../../features/auth/presentation/pages/sessions_page.dart';
import '../../features/auth/presentation/pages/change_password_page.dart';
import '../../features/auth/presentation/pages/delete_account_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/about/presentation/pages/about_page.dart';
import '../../features/credits/presentation/pages/credits_page.dart';
import '../../features/family/presentation/pages/family_join_page.dart';
import '../../features/family/presentation/pages/family_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/owner/presentation/pages/owner_page.dart';
import '../../features/owner/presentation/pages/owner_reports_page.dart';
import '../../features/owner/presentation/pages/owner_rating_bursts_page.dart';
import '../../features/owner/presentation/pages/owner_testers_page.dart';
import '../../features/owner/presentation/pages/owner_review_reports_page.dart';
import '../../features/owner/presentation/pages/owner_shares_page.dart';
import '../../features/owner/presentation/pages/owner_users_page.dart';
import '../../features/recipes/presentation/pages/recipe_detail_page.dart';
import '../../features/shares/presentation/share_page.dart';
import '../../features/shopping/presentation/pages/shopping_page.dart';
import '../../features/receipts/presentation/pages/receipt_page.dart';
import '../network/update_gate.dart';
import '../widgets/system_pages.dart';
import 'unfocus_on_navigation.dart';

/// Screens anyone may open, signed in or not. Email links (App Links) land on /auth/* and /en/auth/*.
bool isPublic(String path) =>
    const {'/login', '/register', '/forgot'}.contains(path) ||
    path.startsWith('/auth/') ||
    path.startsWith('/en/auth/');

/// A family invite link (App Link), in either language.
bool isFamilyJoin(String path) =>
    path == '/family/join' || path == '/en/family/join';

/// Where to send the user, or null to stay. Pure, so it is unit-tested without widgets. [uri] (the full location)
/// lets a signed-out invite link come back after sign-in: /login?next=/family/join?t=...
String? redirectFor(
  String path,
  AuthController auth,
  UpdateGate update, {
  Uri? uri,
}) {
  if (update.required) return path == '/update' ? null : '/update';
  switch (auth.status) {
    case AuthStatus.unknown:
      return isPublic(path) || path == '/splash' ? null : '/splash';
    case AuthStatus.signedOut:
      if (isPublic(path)) return null;
      return isFamilyJoin(path) && uri != null
          ? Uri(
              path: '/login',
              queryParameters: {'next': uri.toString()},
            ).toString()
          : '/login';
    case AuthStatus.signedIn:
      if (const {'/login', '/register', '/splash', '/update'}.contains(path)) {
        final next = uri?.queryParameters['next'];
        return next != null && isFamilyJoin(Uri.parse(next).path) ? next : '/';
      }
      if (path.startsWith('/owner') && !(auth.user?.isOwner ?? false)) {
        return '/';
      }
      return null;
  }
}

GoRouter buildRouter(
  AuthController auth,
  UpdateGate update, {
  List<NavigatorObserver> observers = const [],
}) {
  // Website paths for email links, in both languages: /auth/reset and /en/auth/reset open the same screen.
  List<GoRoute> linkRoutes(String prefix) => [
    _page(
      path: '$prefix/auth/verify',
      builder: (_, s) => VerifyEmailPage(token: s.uri.queryParameters['token']),
    ),
    _page(
      path: '$prefix/auth/reset',
      builder: (_, s) =>
          ResetPasswordPage(token: s.uri.queryParameters['token']),
    ),
    _page(
      path: '$prefix/auth/forgot',
      builder: (_, _) => const ForgotPasswordPage(),
    ),
    _page(
      path: '$prefix/auth/delete',
      builder: (_, _) => const DeleteAccountPage(),
    ),
  ];

  return GoRouter(
    initialLocation: '/',
    observers: [UnfocusOnNavigation(), ...observers],
    refreshListenable: Listenable.merge([auth, update]),
    redirect: (_, state) =>
        redirectFor(state.uri.path, auth, update, uri: state.uri),
    routes: [
      _page(
        path: '/',
        builder: (_, state) => HomePage(open: state.extra),
      ),
      // Opened from Home's map button (no longer a tab).
      _page(
        path: '/map',
        // ?lat=&lng= (a place's pin): the map opens there.
        builder: (_, state) {
          final lat = double.tryParse(state.uri.queryParameters['lat'] ?? '');
          final lng = double.tryParse(state.uri.queryParameters['lng'] ?? '');
          return PlacesMapPage(
            focus: lat == null || lng == null ? null : LatLng(lat, lng),
          );
        },
      ),
      // The shopping list: its own page, opened from Home's shopping-list button.
      _page(path: '/shopping', builder: (_, _) => const ShoppingPage()),
      _page(path: '/splash', builder: (_, _) => const SplashPage()),
      _page(path: '/update', builder: (_, _) => const UpdateRequiredPage()),
      _page(path: '/login', builder: (_, _) => const LoginPage()),
      _page(path: '/register', builder: (_, _) => const RegisterPage()),
      _page(path: '/forgot', builder: (_, _) => const ForgotPasswordPage()),
      ...linkRoutes(''),
      ...linkRoutes('/en'),
      _page(path: '/account', builder: (_, _) => const AccountPage()),
      _page(path: '/settings', builder: (_, _) => const SettingsPage()),
      _page(path: '/usage', builder: (_, _) => const UsagePage()),
      _page(path: '/badges', builder: (_, _) => const BadgesPage()),
      _page(path: '/credits', builder: (_, _) => const CreditsPage()),
      _page(path: '/about', builder: (_, _) => const AboutPage()),
      _page(path: '/family', builder: (_, _) => const FamilyPage()),
      for (final path in const ['/family/join', '/en/family/join'])
        _page(
          path: path,
          builder: (_, s) => FamilyJoinPage(token: s.uri.queryParameters['t']),
        ),
      // Top level, not nested under /account: Account is also a home tab, so pushing this must add one page only.
      _page(
        path: '/account/password',
        builder: (_, _) => const ChangePasswordPage(),
      ),
      _page(path: '/account/email', builder: (_, _) => const ChangeEmailPage()),
      _page(path: '/account/sessions', builder: (_, _) => const SessionsPage()),
      _page(path: '/account/passkeys', builder: (_, _) => const PasskeysPage()),
      _page(path: '/share', builder: (_, _) => const SharePage()),
      _page(
        path: '/receipts/:id',
        builder: (_, state) => ReceiptPage(id: state.pathParameters['id']!),
      ),
      _page(
        path: '/places/:id',
        builder: (_, state) => PlaceDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/recipes/:id',
        pageBuilder: (context, state) {
          final preview = state.extra is RecipePreview
              ? state.extra! as RecipePreview
              : null;
          final page = RecipeDetailPage(
            id: state.pathParameters['id']!,
            preview: preview,
          );
          // From a card with a photo: the photo flies into the page's header (hero) while the page fades in; a
          // page flip would fight it. Anything else opens like every page.
          if (preview?.hasPhoto ?? false) {
            return CustomTransitionPage<void>(
              key: state.pageKey,
              name: state.name ?? state.path,
              restorationId: state.pageKey.value,
              transitionDuration: const Duration(milliseconds: 380),
              reverseTransitionDuration: const Duration(milliseconds: 320),
              child: page,
              transitionsBuilder: (context, animation, _, child) =>
                  FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                    child: child,
                  ),
            );
          }
          return MaterialPage<void>(
            key: state.pageKey,
            name: state.name ?? state.path,
            restorationId: state.pageKey.value,
            child: page,
          );
        },
      ),
      _page(
        path: '/branches/:id/reviews',
        builder: (_, state) =>
            ReviewsPage(branchId: state.pathParameters['id']!),
      ),
      _page(
        path: '/places/:id/pin/:branchId',
        builder: (_, state) => PinPickerPage(
          placeId: state.pathParameters['id']!,
          branchId: state.pathParameters['branchId']!,
        ),
      ),
      _page(
        path: '/owner',
        builder: (_, _) => const OwnerPage(),
        routes: [
          _page(
            path: 'usage',
            builder: (_, _) => const OwnerPage(usageOnly: true),
          ),
          _page(path: 'users', builder: (_, _) => const OwnerUsersPage()),
          _page(path: 'shares', builder: (_, _) => const OwnerSharesPage()),
          _page(path: 'reports', builder: (_, _) => const OwnerReportsPage()),
          _page(
            path: 'review-reports',
            builder: (_, _) => const OwnerReviewReportsPage(),
          ),
          _page(
            path: 'rating-bursts',
            builder: (_, _) => const OwnerRatingBurstsPage(),
          ),
          _page(path: 'testers', builder: (_, _) => const OwnerTestersPage()),
        ],
      ),
    ],
  );
}

// go_router 18 recognises MaterialApp only from package:material_ui, not this app's flutter/material one, so its
// default pages have no transition. Building flutter MaterialPages here lets the theme's book page turn run.
GoRoute _page({
  required String path,
  required GoRouterWidgetBuilder builder,
  List<RouteBase> routes = const [],
}) => GoRoute(
  path: path,
  routes: routes,
  pageBuilder: (context, state) => MaterialPage<void>(
    key: state.pageKey,
    name: state.name ?? state.path,
    restorationId: state.pageKey.value,
    child: builder(context, state),
  ),
);
