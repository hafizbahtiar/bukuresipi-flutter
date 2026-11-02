# bukuresipi-flutter

The Bukuresipi app (Android + iOS). API: `bukuresipi-hono`; website and email-link pages: `bukuresipi-astro`.

## Setup

```sh
cp .env.example .env        # API_BASE_URL=https://api.bukuresipi.com (every build, debug included)
flutter pub get
dart run build_runner build # envied -> lib/core/env/env.g.dart; re-run after editing .env*
flutter run
flutter test
```

## Layout (feature-first, clean layers)

- `lib/main.dart` - composition root: the only place concrete classes are built and wired (Provider).
- `lib/core/` - shared: `env/` (envied), `network/` (Dio `ApiClient`: app-version header, bearer token, single-flight
  refresh, `ApiException`, 426 `UpdateGate`), `storage/` (tokens in secure storage), `settings/` (language, shared
  preferences), `router/` (go_router + redirect rules), `theme/`, `widgets/`.
- `lib/features/<feature>/`
  - `domain/` - entities + repository interface. No Flutter, no Dio.
  - `data/` - API calls + the repository implementation (JSON -> entity).
  - `presentation/` - ChangeNotifier controller + pages/widgets. Depends on `domain/` only.
- `lib/l10n/` - `app_ms.arb` / `app_en.arb` (Malay default). Generated on build (`flutter gen-l10n`).
- `test/` mirrors `lib/`; `test/fakes.dart` has a fake Dio adapter and a fake repository.

No use-case classes and no DI container: a repository method is the use case, Provider is the container. Local
database (drift) is not added yet; add it with the first offline feature.

## Icon and splash

Source: `assets/brand/` (from the website logo, `bukuresipi-astro/public/favicon.svg`): `icon.png` (iOS + legacy
Android), `adaptive.png` (Android adaptive foreground on pandan), `mark.png` (splash). After changing them:
`dart run flutter_launcher_icons && dart run flutter_native_splash:create`. Config is in `pubspec.yaml`.
No flavors yet: every build uses `.env` (production API).

## Email links

Verify/reset emails link to `https://bukuresipi.com/auth/...` (and `/en/auth/...`). With the app installed these open
the app (Android App Links, iOS Universal Links); otherwise the website page. For this to work the website must serve
`/.well-known/assetlinks.json` (release SHA-256 cert fingerprint, package `com.bukuresipi`) and
`/.well-known/apple-app-site-association` (`<TeamID>.com.bukuresipi`, paths `/auth/*`, `/en/auth/*`).
