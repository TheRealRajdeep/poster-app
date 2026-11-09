# poster-app

A free Android app that lets anyone make a personalized festival or birthday wish poster, already showing their own photo and name, and post it to WhatsApp Status in a few taps.

- **Progress:** [CHECKLIST.md](CHECKLIST.md). Each item is ticked as soon as it's done.
- **Why things are the way they are:** [docs/DECISIONS.md](docs/DECISIONS.md)
- **Work tracking:** GitHub Issues, grouped by milestone (M0–M9). Issues labelled `ui` wait for design input before work starts.

## Layout (planned)
```
packages/poster_spec      spec.json models + validation
packages/poster_renderer  (spec + scene + profile) → image
packages/wa_share         Android share request aimed at WhatsApp
lib/features/*            onboarding, feed, wish_someone, poster_view, profile, ads, referrals
factory/                  Python nightly scene + spec generator
```
