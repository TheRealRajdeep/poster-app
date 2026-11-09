# Design decisions

Locked during the design session on 2026-11-10. Change these only on purpose, and record why.

## Product
- **Audience:** middle-aged and senior users in India, plus small-time politicians and small businesses, who share wish posters for festivals and birthdays on WhatsApp Status and groups.
- **Platform:** Android first. iOS may come later from the same Flutter code.
- **Money:** fully free with ads. Optional extras later: ₹49/month with no ads, or 5 referrals = 1 month with no ads + 1 AI poster. Politicians are not expected to pay; businesses may.
- **No watermark.** Growth comes from a referral caption that is attached to each share (on by default, can be switched off).

## UX
- **One-time setup:** language → "Which festivals do you celebrate?" (choose several; never asks for religion) → photo (auto cut-out) → name + optional subtitle.
- **Personalized feed:** every poster already shows the user's photo and name. Tap a poster → big **WhatsApp Status** button.
- **2 tabs:** Home (festivals + daily posters) and Wish someone (birthdays/anniversaries for another person). Profile sits behind the avatar.
- **No editor in the main flow.** An optional Edit option stays hidden by default.
- Festival preferences **stay on the phone** and are **never passed to the ad SDK** (Google ad policy forbids targeting by religion).

## Posters
- **AI never draws text.** A poster = a text-free AI scene (`scene.webp`) + `spec.json` (the slots for photo and text) + the user's profile, put together **on the phone** by `poster_renderer`.
- **Batch "template factory"** (Python, nightly): ~30 layout archetypes → scenes generated with the slot areas left empty → automated QA (are slot areas calm, colour contrast, overflow test with long names in every script) → ~5% checked by a human → publish.
- **Live AI generation** for each user is a gated extra (reward ad / referral reward) and returns the same scene + spec format.

## Share
- An Android share request aimed only at `com.whatsapp` / `com.whatsapp.w4b`. When both are installed, the user picks once and the choice is remembered. Falls back to the standard share menu.
- Secondary options: send to a group or chat, save to gallery, more apps.

## Photo cut-out
- Google ML Kit cut-out on the phone for an instant preview → one-time cut-out on the server for the final clean version. The original photo is deleted from the server right away; the cut-out PNG is stored on the phone.

## Backend
- Firebase: anonymous sign-in (no sign-up), Firestore, Remote Config, Crashlytics, Analytics, Cloud Messaging, AdMob.
- Cloudflare R2 + CDN for scene images (no download fees).
- Referrals: Play Install Referrer API (Firebase Dynamic Links has been shut down).

## Content
1. Festivals and national days, filtered by festival choices, language and region; shown from 3 days before.
2. Daily posters: Good Morning / Suvichaar + day-of-week devotion + lunar-calendar days.
3. Personal: saved birthdays with a reminder on the morning of the day.
- At most 1 notification a day (~6–7 am).

## Ads
- Native ads every 6–8 cards in the feed.
- App-open ad only from the 2nd session onward, and never when the app is opened from a notification.
- Never an ad between choosing a poster and sharing it. All ad logic lives in `features/ads` behind `AdsPolicy`; frequency is controlled through Remote Config.

## Languages
- English, Hindi, Marathi, Gujarati, Kannada, Telugu, Tamil. Each has its own Remote Config switch and goes live only after a native reviewer approves it.

## Code
- Flutter + Riverpod, organised by feature (`data/ → domain/ → ui/`). Features never import each other.
- Separate packages: `poster_spec`, `poster_renderer` (pure, deterministic, snapshot-tested), `wa_share` (Android plugin).
- `factory/` (Python) is fully separate and shares the spec JSON Schema.

## Open questions
- Referral economics (once the real cost per user is known).
- Exact ad frequency limits (adjustable through Remote Config).
