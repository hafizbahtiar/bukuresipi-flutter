# Pages plan

Status: plan, 2026-11-02. Auth is built (see "Done"). Everything else waits on the API work listed beside it.

## Done (feat/auth)

| Route | Page |
|---|---|
| `/login`, `/register`, `/forgot` | sign in, create account, ask for a reset link |
| `/auth/reset`, `/auth/verify` (+ `/en/...`) | email links (App Links / Universal Links from bukuresipi.com) |
| `/account`, `/account/password` | profile, email confirmation (resend), language, change password, sign out, owner entry |
| `/update` | shown after any 426 `update_required` |
| `/owner` | placeholder, owner role only |

## Standard pages (every user)

Order = build order. Bottom navigation: Book, Map; Account is the person icon in each tab's app bar.

1. **Share in** (Android share sheet / iOS share extension -> `POST /api/v1/shares`). The app's main entrance: a user
   shares a TikTok/IG/FB/YouTube post or a screenshot. Needs `receive_sharing_intent` (or similar) + an iOS share
   extension target. API: exists.
2. **Share status** `/shares/:id`: pending -> done / gap ("we could not read this post"). Poll `GET /shares/:id`.
   API: exists.
3. **Book** `/` (home, Book tab): the user's saved places, newest first: **done**. Recipes join it once recipe import
   is built (`recipe_import_not_built`).
4. **Place** `/places/:id`: name, branches, halal claim shown as a quote with its source link (never a badge saying
   "halal"), the user's note (`PATCH`), remove (`DELETE`), directions (Google Maps): **done**.
5. **Map** (Map tab): a pin per branch with lat/lng; branches without coordinates are listed from a card at the
   bottom: **done**. `maplibre_gl` + OpenFreeMap vector tiles (free, no key, no request cap; OSM's own tile servers
   do not allow app traffic).
6. **Recipe** `/recipes/:id`: ingredients, steps, source link. API: **missing** (recipe feature not built).
7. **Account**: done.

## Owner pages (role `owner`; the API must also check `requireRole('owner')`)

None of these have API endpoints yet. Smallest useful set, in order:

1. **Overview** `/owner`: users total / new this week, shares today, failures (gaps) today, metered usage vs caps this
   month (`system_subscription` meters: AI, search, geocoding, email). One `GET /api/v1/owner/stats`.
2. **Usage caps** `/owner/meters`: see and change each meter's monthly cap (stop spending when a provider bill climbs).
   `GET/PATCH /api/v1/owner/meters`.
3. **AI settings** `/owner/ai`: which provider + model per use case (today `AI_ROUTES` is code). Needs `AI_ROUTES`
   moved to a table first; until then changing a model is a deploy, which is fine for one owner. **Recommend: skip
   until a model change is actually needed more than once a month.**
4. **Users** `/owner/users`: search by email, see verified / created / share count; end a user's sessions. No role
   editing (one owner, by seed). `GET /api/v1/owner/users`, `POST /api/v1/owner/users/:id/logout`.
5. **Failed shares** `/owner/shares?status=gap`: what the pipeline could not read, to tune thresholds. Read only.

Skipped on purpose: admin role, permissions, editing other users' data, broadcast messages.
