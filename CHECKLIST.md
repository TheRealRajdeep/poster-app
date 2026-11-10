# Checklist

Tick an item **as soon as it's done** and close its issue. Items labelled `ui` need design input from the owner before work starts.

## M0 Setup: Toolchain and repo scaffold

- [x] [#1](https://github.com/TheRealRajdeep/poster-app/issues/1) Install Flutter + Android Studio; flutter doctor all green
- [x] [#2](https://github.com/TheRealRajdeep/poster-app/issues/2) Scaffold Flutter app + packages/ layout (poster_spec, poster_renderer, wa_share)
- [x] [#3](https://github.com/TheRealRajdeep/poster-app/issues/3) CI: GitHub Actions running flutter analyze + tests on every push

## M1 Thin slice: One bundled spec -> renderer -> WhatsApp Status share on a real low-end phone

- [x] [#4](https://github.com/TheRealRajdeep/poster-app/issues/4) poster_spec: Dart models + JSON Schema + validation
- [x] [#5](https://github.com/TheRealRajdeep/poster-app/issues/5) poster_renderer: compose scene + photo slot + text slots into a PNG
- [x] [#6](https://github.com/TheRealRajdeep/poster-app/issues/6) Indian-script fonts: bundle body + display fonts for hi, mr, gu, kn, te, ta, en
- [ ] [#49](https://github.com/TheRealRajdeep/poster-app/issues/49) Choose decorative 'script' and 'ornate' poster fonts per language `ui`
- [ ] [#7](https://github.com/TheRealRajdeep/poster-app/issues/7) Text effects: stroke, gradient/glitter fill, shadow/glow, auto-fit to box
- [ ] [#8](https://github.com/TheRealRajdeep/poster-app/issues/8) Snapshot tests: long names in every script, overflow cases
- [ ] [#9](https://github.com/TheRealRajdeep/poster-app/issues/9) Hand-made sample scene + spec (1 archetype)
- [ ] [#10](https://github.com/TheRealRajdeep/poster-app/issues/10) wa_share plugin: share request aimed at com.whatsapp / com.whatsapp.w4b + fallback share menu
- [ ] [#11](https://github.com/TheRealRajdeep/poster-app/issues/11) Spike: does the caption survive a Status share on current WhatsApp builds?
- [ ] [#12](https://github.com/TheRealRajdeep/poster-app/issues/12) Debug test screen: render sample + share button `ui`
- [ ] [#13](https://github.com/TheRealRajdeep/poster-app/issues/13) Test on a real low-end phone: render time + full share flow

## M2 Onboarding & profile: Real personalization

- [ ] [#14](https://github.com/TheRealRajdeep/poster-app/issues/14) Onboarding screens design (language, festivals, photo, name) `ui`
- [ ] [#15](https://github.com/TheRealRajdeep/poster-app/issues/15) Profile model + local storage (festivals never leave the device)
- [ ] [#16](https://github.com/TheRealRajdeep/poster-app/issues/16) On-phone cut-out with ML Kit Subject Segmentation
- [ ] [#17](https://github.com/TheRealRajdeep/poster-app/issues/17) Localization setup (ARB files, 7 languages) + language switches in Remote Config

## M3 Remote feed: Posters from Firestore + R2

- [ ] [#18](https://github.com/TheRealRajdeep/poster-app/issues/18) Firebase project: anonymous sign-in, Firestore, Remote Config, Crashlytics, Analytics
- [ ] [#19](https://github.com/TheRealRajdeep/poster-app/issues/19) Cloudflare R2 bucket + CDN domain for scenes
- [ ] [#20](https://github.com/TheRealRajdeep/poster-app/issues/20) Firestore data model (posters, occasions) + security rules
- [ ] [#21](https://github.com/TheRealRajdeep/poster-app/issues/21) Feed repository: query by occasion/language/festival, pagination, caching
- [ ] [#22](https://github.com/TheRealRajdeep/poster-app/issues/22) Preview-render cache: small previews in the feed, full render on share
- [ ] [#23](https://github.com/TheRealRajdeep/poster-app/issues/23) Home feed + poster view + share buttons design `ui`
- [ ] [#24](https://github.com/TheRealRajdeep/poster-app/issues/24) Hand-make ~30 specs across 3 archetypes (QA reference set)

## M4 Factory: Content at scale without hand design

- [ ] [#25](https://github.com/TheRealRajdeep/poster-app/issues/25) Factory skeleton (Python) + archetype library format
- [ ] [#26](https://github.com/TheRealRajdeep/poster-app/issues/26) Scene generation with empty slot areas; pick model + measure cost per image
- [ ] [#27](https://github.com/TheRealRajdeep/poster-app/issues/27) Automated QA: calm slot areas, contrast colour picking, long-name overflow render
- [ ] [#28](https://github.com/TheRealRajdeep/poster-app/issues/28) Publisher: scene.webp to R2, spec to Firestore, 5% human spot-check queue
- [ ] [#29](https://github.com/TheRealRajdeep/poster-app/issues/29) Scheduled nightly job: next 7 days of occasions

## M5 Calendar & retention: A reason to open the app every day

- [ ] [#30](https://github.com/TheRealRajdeep/poster-app/issues/30) Occasions collection: festival date table for target regions
- [ ] [#31](https://github.com/TheRealRajdeep/poster-app/issues/31) Daily layer: Good Morning/Suvichaar + day-of-week devotion + lunar-calendar days
- [ ] [#32](https://github.com/TheRealRajdeep/poster-app/issues/32) Greeting text library per language + native-reviewer sign-off
- [ ] [#33](https://github.com/TheRealRajdeep/poster-app/issues/33) Morning notification (at most 1/day) via FCM

## M6 Ads: Revenue without friction

- [ ] [#34](https://github.com/TheRealRajdeep/poster-app/issues/34) AdMob integration inside features/ads behind AdsPolicy
- [ ] [#35](https://github.com/TheRealRajdeep/poster-app/issues/35) Placements: native ads in feed, app-open ad (2nd session+), Remote Config frequency limits `ui`

## M7 Release: Closed beta then Play Store

- [ ] [#36](https://github.com/TheRealRajdeep/poster-app/issues/36) Privacy policy + Play Data Safety form
- [ ] [#37](https://github.com/TheRealRajdeep/poster-app/issues/37) Closed beta via Play internal testing
- [ ] [#38](https://github.com/TheRealRajdeep/poster-app/issues/38) Play Store listing in 7 languages `ui`
- [ ] [#48](https://github.com/TheRealRajdeep/poster-app/issues/48) Replace placeholder app ID com.example.posterapp before first Play upload

## M8 Wish someone: Birthdays for others (politicians, community)

- [ ] [#39](https://github.com/TheRealRajdeep/poster-app/issues/39) Wish someone tab design `ui`
- [ ] [#40](https://github.com/TheRealRajdeep/poster-app/issues/40) System contact picker + 2nd-person photo + cached cut-out
- [ ] [#41](https://github.com/TheRealRajdeep/poster-app/issues/41) Two-person archetypes in the factory
- [ ] [#42](https://github.com/TheRealRajdeep/poster-app/issues/42) Saved birthdays + morning-of reminders

## M9 Extras: Upgrades after launch

- [ ] [#43](https://github.com/TheRealRajdeep/poster-app/issues/43) Server cut-out service (BiRefNet on Cloud Run); delete originals right away
- [ ] [#44](https://github.com/TheRealRajdeep/poster-app/issues/44) Referrals via Play Install Referrer + referral link in caption
- [ ] [#45](https://github.com/TheRealRajdeep/poster-app/issues/45) No-ads plan (Rs 49/month) via Play Billing + referral reward
- [ ] [#46](https://github.com/TheRealRajdeep/poster-app/issues/46) Live AI generation (gated by reward ad / referral)
- [ ] [#47](https://github.com/TheRealRajdeep/poster-app/issues/47) Referral economics: cost per user vs referral value
