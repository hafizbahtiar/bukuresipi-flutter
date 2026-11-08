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

## Release (Android)

`./setup.sh` asks apk/aab and dev/prod, then cleans, builds and copies the file to `apk/` or `aab/` as
`bukuresipi-v<version>(<code>).aab` (`-dev` for a debug build). Prod needs `android/key.properties` (upload key in
`~/Documents/Keystore`). Raise `version:` in `pubspec.yaml` before every upload: the `+code` must go up each time.

### Release notes (Play Console)

Paste the whole block into "Release notes". Play keeps each language to 500 characters.

#### 1.0.4 (6)

```
<ms-MY>
• Butang + baharu: tampal pautan, tangkapan skrin, resit atau taip resipi.
• Resit: ambil gambar resit kedai makan, simpan lawatan dan lihat perbelanjaan anda.
• Pautan Google Maps: tampal di laporan lokasi untuk pin yang tepat.
• Negeri dan bandar dipilih dari senarai rasmi.
• Butang peta di Buku dan halaman kedai.
• Akaun dan Tetapan kini halaman berasingan.
• Kedai bernama hampir sama tidak lagi bercampur.
• Pembaikan dan prestasi.
</ms-MY>
<en-US>
• New + button: paste a link, a screenshot, a receipt or type a recipe.
• Receipts: snap a restaurant receipt, save the visit and see your spending.
• Google Maps links: paste one in a location report for an exact pin.
• State and town are picked from the official list.
• A map button on Book and on a place's page.
• Account and Settings are now separate pages.
• Shops with similar names are no longer mixed up.
• Fixes and speed.
</en-US>
```

#### 1.0.0 (1): first closed test

```
<ms-MY>
Versi pertama Bukuresipi (ujian tertutup).
• Kongsi pautan TikTok, Facebook, Instagram, YouTube, laman web atau tangkapan skrin: kami jadikan resipi atau simpan kedai makan.
• Peta kedai simpanan anda dan kedai berdekatan.
• Penilaian dan ulasan cawangan.
• Buku keluarga: kongsi resipi dan senarai beli-belah (hingga 3 orang).
• Notifikasi bila kongsian siap.
• Log masuk dengan Google.
Jumpa masalah? Beritahu kami. Terima kasih kerana menguji!
</ms-MY>
<en-US>
The first Bukuresipi release (closed test).
• Share a TikTok, Facebook, Instagram, YouTube or web link, or a screenshot: we turn it into a recipe or save the restaurant.
• A map of your saved restaurants, and places nearby.
• Branch ratings and reviews.
• Family book: share recipes and a shopping list (up to 3 people).
• A notification when your share is ready.
• Sign in with Google.
Found a problem? Tell us. Thanks for testing!
</en-US>
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

## Share to Bukuresipi

`features/shares`: the OS share sheet (receive_sharing_intent) -> `ShareIntake` (takes the first https link out of
shared text, or the image; ignores our own bukuresipi.com links) -> `POST /api/v1/shares` once signed in (a share made
while signed out waits for sign-in) -> `/share` screen polls `GET /api/v1/shares/:id` until the post is read.

- **Android**: done (`SEND` text/plain + image/* filters in AndroidManifest.xml, `singleTask`).
- **iOS**: needs a Share Extension target, which only Xcode + your Apple team can set up. In Xcode (`ios/Runner.xcworkspace`):
  1. File > New > Target > Share Extension, name `Share Extension`, bundle id `com.bukuresipi.ShareExtension`,
     deployment target = Runner's. Do not activate the scheme.
  2. Runner and Share Extension targets > Signing & Capabilities > + App Groups > `group.com.bukuresipi`.
  3. Replace `ios/Share Extension/ShareViewController.swift` with:
     `import receive_sharing_intent` / `class ShareViewController: RSIShareViewController {}`
  4. `ios/Share Extension/Info.plist`: add `AppGroupId` = `$(CUSTOM_GROUP_ID)` and the `NSExtensionActivationRule`
     (links + 1 image) from the receive_sharing_intent README; Runner `Info.plist`: `AppGroupId` and the
     `CFBundleURLTypes` entry `ShareMedia-$(PRODUCT_BUNDLE_IDENTIFIER)`.
  5. Podfile: add the `Share Extension` target (`inherit! :search_paths`), set `CUSTOM_GROUP_ID = group.com.bukuresipi`
     in both targets' build settings, then `cd ios && pod install`.
  Full steps: https://pub.dev/packages/receive_sharing_intent (iOS section).

## Email links

Verify/reset emails link to `https://bukuresipi.com/auth/...` (and `/en/auth/...`). With the app installed these open
the app (Android App Links, iOS Universal Links); otherwise the website page. For this to work the website must serve
`/.well-known/assetlinks.json` (release SHA-256 cert fingerprint, package `com.bukuresipi`) and
`/.well-known/apple-app-site-association` (`<TeamID>.com.bukuresipi`, paths `/auth/*`, `/en/auth/*`).
