# bukuresipi-flutter

The Bukuresipi app (Android first; iOS needs the share extension, see README). Flutter + Provider + go_router + Dio.
API: `../bukuresipi-hono` (its `CLAUDE.md` is the source of truth for every endpoint and rule the app shows);
website + email-link pages: `../bukuresipi-astro`. Setup, release, release notes, share intake, App Links: `README.md`.

## Commands

| Command | Does |
|---|---|
| `flutter analyze` | must say "No issues found!" before a commit |
| `flutter test` | all tests; CI (`.github/workflows/check.yml`) runs gen-l10n, build_runner, analyze, test |
| `flutter test --dart-define=TEST_SIZE=1280x800` | every test at that screen size (tablet / landscape); look for "overflowed" |
| `flutter gen-l10n` | after editing `lib/l10n/app_en.arb` / `app_ms.arb` (also runs on build) |
| `dart run build_runner build` | envied -> `lib/core/env/env.g.dart`, after editing `.env*` |
| `dart fix --apply && dart format lib test` | after a move or rename: unused imports, formatting |
| `./setup.sh` | release build (apk/aab, dev/prod) into `apk/` or `aab/`; raise `version:` `+code` first |

## Structure (feature-first)

- `lib/main.dart` - composition root: the only place concrete classes are built and wired (Provider).
- `lib/app.dart` - MaterialApp, theme, localizations (`MalayTimeDelegate` before the global ones).
- `lib/core/` - shared, knows no feature: `network/` (ApiClient, ApiException, 426 UpdateGate), `router/`,
  `settings/`, `storage/`, `env/`, `ads/`, `theme/` (`app_theme.dart` = `Notebook.of(context)` colours and fonts;
  `app_theme_constant.dart` = spacing `spaceXs/S/M/L`, `wideFrom` 600, `readableWidth`, `sidePanelWidth`,
  `isWide(context)`), `utils/` (log, open a link, `formatTime`, `imageSubtype`), `widgets/` (the house components, below).
- `lib/features/<feature>/` - `domain/` (entities + repository interface; no Flutter, no Dio), `data/` (API calls +
  repository impl, JSON -> entity), `presentation/` (ChangeNotifier controller, `pages/`, `widgets/`).
- `lib/l10n/` - `app_ms.arb` (Malay, the default) + `app_en.arb`; generated into `lib/l10n/gen/`.
- `test/` mirrors `lib/`; `test/fakes.dart` = fake Dio adapter + fake repositories; most features have `test/features/<f>/<f>_fixtures.dart`.

Dependency rule: a feature imports `core/` and another feature's `domain/` or its public widgets; `core/` never
imports a feature. A widget used by several features stays in the feature whose state it reads (`ShareImage`,
`Avatar`, `HalalStatus`, `NearbySheet`); it moves to `core/widgets/` only when it reads no feature data.
No use-case classes, no DI container: a repository method is the use case, Provider is the container.

Receipt e-invoice QR (`features/receipts/data/receipt_qr.dart`): the photo is read quietly with ML Kit at upload;
missed = the receipt's Scan button opens Google's live code scanner (Play services, no camera permission; channel
`bukuresipi/qr` in `MainActivity`), a phone without it takes a close-up photo. A link's site is shown before opening;
http, short links and look-alike names ask first (`domain/einvoice_link.dart`).

Pasar (`features/places/domain/market.dart`, `widgets/market_*.dart`, `markets_card.dart`): today and "open now" are
computed here on Malaysia time (`malaysiaNow`, a phone abroad stays right), last night's opening past midnight counts;
no days = "not known", never closed. Home's card = what is still on today within 10 km (no card under a search or
filter); the map has its own `markets` source under the pins (street/ground + dot, for every user), reloaded when the
camera moves 7.5 km; `?market=<branch>` opens that sheet. Owner: Edit branch > Days, shown only once the server says it
is a market (a failed read = no tab, so an empty editor can never overwrite saved days).

Notifications (`features/notifications/`): Home's bell (`InboxBell`, a dot while something is new) opens the inbox:
every push a phone got plus the owner's messages; opening it marks all read; a row's ⋮ removes it from this user's
inbox only. A row opens what its push opens
(`push/push_routes.dart` `pushPath`, shared with `app.dart`; a share push goes to `PushController.onTap`). Owner:
Owner > Send notifications (a template first, `msgTpl1..10` in the arbs, 1 = app update sent as kind `update`:
a tap runs `updateApp`; To: everyone or a picked user) or Users > a user > Send a notification (`MessageSheet`);
an optional photo (a step of `MessageSheet`, uploaded as multipart; shown in the push and the inbox row, public URL);
always inbox + push, pushed by the send itself (a big broadcast's rest by the cron). A push in the open app: a banner
with Open (`pushPath`) and `inboxChanged` re-reads the bell.

Product photos: `CataloguePhoto(id)` (`core/widgets/catalogue_photo.dart`, public link, disk cache, ≤512 px so no
resize) on the picker, "see all products" and the shopping row; the owner sets one on the product form (camera /
photos, or Open Food Facts' from the fill, sent after Save). Credits names Open Food Facts (CC BY-SA photos).
Brand logos: the brand form's photo field + "Cari logo dengan AI" (pictures from its site, tap one), sent after Save;
a product without its own photo shows its brand's logo (the server picks), a brand pick shows its logo.

Ingredients (owner): Owner > Bahan dan nama lain (`owner_ingredient_list_page.dart`, also the gaps page's ⋮) lists
every ingredient; its page (`owner_ingredient_page.dart`, `/owner/ingredient/:id`) only shows (tabs: other names,
may be the same); Edit (`owner_ingredient_edit_page.dart`, `/:id/edit`, EditTabs) renames (the old name stays as
another name) and sets the category (the check saves), adds a name, removes a wrong one (asks with how many lines go
back to the gaps), or makes a name that is another food its own ingredient ("limau nipis" off Limau: its lines move there).

## House components (`core/widgets/`; use them, never a native copy)

`import '.../core/widgets/base.dart'` gives all of `base/`:
- `sheets.dart` - `showBaseSheet` (floating by default; it draws the handle and keeps itself above the keyboard,
  so a sheet's content never pads for `viewInsets`; a change of its content's height moves its top edge),
  `SheetSwitcher` (steps inside one sheet: a menu, then the picked row's next step; never close a sheet to open
  the next one; `docs/motion.md` 5; each step's `SheetStepTitle` has Back to the step before, sliding the other
  way), `PhotoSourceTiles` (camera or photos, as a step) and `showPhotoSourceSheet`
  (the same as a sheet of its own). Never `showModalBottomSheet`.
- `dialog.dart` - `showBaseDialog(message, tone: DialogTone.info|confirm|danger)`. Never `showDialog`/`AlertDialog`.
- `picker.dart` - `showBasePicker`, `PickerField`. `menus.dart` - `MenuAction`, `MoreMenu`, `showActionSheet`
  (a ⋮ opens this, never a Material popup menu).
- `tiles.dart` - `SectionHeader`, `BaseTile`, `TagChip`/`TileTag`/`TagTone`, `InfoCard`.
  `tabs.dart` - `DetailTabs`, `EditTabs`, `PinnedBar`, `DetailSection`. `owner.dart` - `OwnerStrip`, `DeleteScopeCard`.
- Others: `notebook.dart` (`NotebookTitle`, the older `NotebookPage`/`NotebookRow`/`NotebookHeading`/
  `NotebookSegmented` page look), `wide_page.dart`, `cover_app_bar.dart`, `hero_motion.dart`, `photo_sheet.dart`,
  `load_view.dart`, `skeleton.dart`, `glass_bar.dart`. Motion and why: `docs/motion.md`.

## UI rules

- Every page title is the handwritten `NotebookTitle` (`AppBar(toolbarHeight: 76, title: NotebookTitle(t))`);
  photo detail pages use `Notebook.of(context).hand`. Never swap it for plain `Text`.
- Inside a floating sheet the gutter is `spaceM`, not `notebookGutter` (that is the notebook page's margin line).
- Sizes come from `app_theme_constant.dart`; no new magic numbers for spacing or breakpoints.
- Responsive: below 600 px a bottom bar, from 600 a navigation rail; the map's sheet becomes a left column
  (`sidePanelWidth`); reading pages cap at `readableWidth` (`WidePage`). Check a change at 320 px wide and at
  `TEST_SIZE=1280x800`.
- Times via `formatTime(context, dt)` (12/24 h from the phone; AM/PM in Malay too). Every string in both arb files.
- Owner tools (Check JAKIM, AI draft, picks) go on Edit place / Edit branch; detail pages only show information.
  Owner panels: `places/presentation/widgets/owner_panel.dart` (`OwnerPanel`, `BusyButton`, `PanelActions`: negative left, positive right).
  One main action per row; the rest behind ⋮ -> `showActionSheet`.
- Before calling UI work done: render every state (idle, loading, result, empty, error, a 320 px phone) with a
  temporary golden test, look at each image, then delete the test.
- Halal is a quoted claim with its source, never a "halal" badge; JAKIM's certificate is per branch.

## Workflow

- Branch from `development` (`feat/...`, `fix/...`, `refactor/...`); `main` is release only. Check
  `git branch --show-current` before every commit: something on this machine pushes `main`.
- An API change that breaks older apps raises the backend's `MIN_APP_VERSION` only once this app's new version is
  live on Play.
