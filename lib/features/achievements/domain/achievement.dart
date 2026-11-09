/// What a badge counts. The counts and their tier steps live on the server (design: bukuresipi-hono
/// `docs/superpowers/specs/2026-11-09-achievements-design.md`); the app draws them. Art: `design/badges/build.py`.
enum AchievementCategory { explorer, traveller, regular, cook, critic, helper }

/// Lowest first; the badge shows index + 1 stars.
enum AchievementTier { bronze, silver, gold, platinum, diamond }
