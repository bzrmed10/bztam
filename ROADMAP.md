# Bztam — Roadmap

One task = one commit. Mark `[x]` when committed and CI is green. Progress is summarized in `REPORT.md`. A TestFlight build goes out at the end of each milestone.

## Milestone 0 — Foundation ✅
- [x] M0.1 README
- [x] M0.2 SPEC.md, ROADMAP.md, REPORT.md
- [x] M0.3 Xcode project via XcodeGen: app `Bztam`, share extension `BztamShare`, unit and UI tests, iOS 26, App Group, placeholder screens and icon
- [x] M0.4 CI: build + test + screenshots on every push
- [x] M0.5 TestFlight workflow: temporary signing via the API, archive, upload
- [x] M0.6 Setup guide (`docs/SETUP.md`)

## Design ✅
- [x] D.1 Design canvas of all screens (Wise-style) and the "Bztam" design system, approved
- [x] D.2 Apple Watch app removed from v1

## Milestone 1 — Core money → TestFlight 1
- [x] M1.1 Design system in SwiftUI: color tokens, type styles, spacing, radius, pill button, icon circle, row, chip, progress bar
- [x] M1.2 L10n table (en/fr) with tests: every string exists, placeholders match; money formatting (2,760 DH / 2 760 DH)
- [x] M1.3 Data layer: SwiftData models (`Entry`, `Category`, `Settings`) in the App Group store, amounts in centimes, default categories
- [x] M1.4 `BudgetCalculator`: periods from payday, money in / spent / left, per category left/over/paid, not planned + unit tests
- [x] M1.5 App shell: flat tab bar (Home, Activity, Insights, Settings), empty states
- [x] M1.6 Onboarding: payday, money in, plan your month
- [x] M1.7 Home: hero, quick actions, category list, previous periods
- [x] M1.8 Add sheet: manual expense and money in (keypad, chips, date, shop/note)
- [x] M1.9 Category detail + edit budget; edit and delete entries with Undo
- [ ] M1.10 Demo data, UI-test screenshots (en/fr), TestFlight build 1 (screenshots done; TestFlight blocked: API key 401)

## Milestone 2 — Scan receipts and screenshots → TestFlight 2
- [x] M2.1 Attachment storage (compressed images in the App Group)
- [x] M2.2 Camera: VisionKit document scanner
- [x] M2.3 Text recognition service (Vision, fr/en)
- [x] M2.4 `ReceiptParser` + unit tests with Moroccan receipts and bills (Marjane, Carrefour, BIM, Inwi, Orange, IAM, Lydec/Redal, Glovo, Jumia)
- [x] M2.5 Scan review screen
- [x] M2.6 Screenshot import from Photos + "Add this screenshot?" prompt
- [ ] M2.7 TestFlight build 2 (CI green; TestFlight waits for the API key fix)

## Milestone 3 — Share extension and PDF bills → TestFlight 3
- [x] M3.1 Share extension (images and PDFs) → App Group inbox → review screen
- [x] M3.2 PDF bills: PDFKit text, OCR fallback
- [ ] M3.3 TestFlight build 3 (CI green; waits for the API key fix)

## Milestone 4 — Activity, Insights, safety → TestFlight 4
- [x] M4.1 Activity: entries by day, search, filter chips
- [x] M4.2 Insights: donut by category, in vs out, vs previous period
- [x] M4.3 Category alerts at 80% and 100% (local notifications)
- [x] M4.4 Face ID lock
- [x] M4.5 Settings: payday, currency, categories editor (add, rename, icon, reorder, archive), language, about
- [ ] M4.6 TestFlight build 4 (CI green; waits for the API key fix)

## Milestone 5 — Smart (on-device AI) → TestFlight 5
- [x] M5.1 Merchant → category memory (learns from choices)
- [x] M5.2 Foundation Models receipt extraction and category guess when available (rules stay the fallback)
- [x] M5.3 Duplicate warning
- [x] M5.4 Type it: "taxi 20", "café 38", Darija in Latin letters → expense draft (parser + tests)
- [x] M5.5 Say it: dictation (fr/en) into the same parser
- [x] M5.6 Siri / Shortcuts: add an expense with App Intents
- [x] M5.7 Monthly recap text and pace warnings
- [x] M5.8 Budget suggestions from the last 2–3 periods
- [ ] M5.9 TestFlight build 5 (CI green; waits for the API key fix)

## Milestone 6 — Recurring and planning → TestFlight 6
- [ ] M6.1 Recurring entries (rent, salary, subscriptions, bills): model, auto-add on their day, edit once or all
- [ ] M6.2 Subscription detection → "Make this recurring?"
- [ ] M6.3 Move money between categories
- [ ] M6.4 TestFlight build 6

## Milestone 7 — Ask Bztam → TestFlight 7
- [ ] M7.1 Query functions over entries (by merchant, category, period, kind) + tests
- [ ] M7.2 Ask screen: questions answered by the on-device model calling those functions; numbers always from code
- [ ] M7.3 TestFlight build 7

## Milestone 8 — Dart (tontine) tracker → TestFlight 8
- [ ] M8.1 Dart model: members, monthly amount, turn order, start month
- [ ] M8.2 Dart screens: list, detail (this month: who paid, whose turn), create/edit
- [ ] M8.3 Link to money: paying creates an expense, receiving creates money in
- [ ] M8.4 Reminders (local notifications)
- [ ] M8.5 TestFlight build 8

## Milestone 9 — Data → TestFlight 9
- [ ] M9.1 iCloud sync (SwiftData + CloudKit private database)
- [ ] M9.2 Export CSV and PDF (period or all)
- [ ] M9.3 TestFlight build 9

## Milestone 10 — App Store readiness
- [ ] M10.1 Privacy manifests, permission strings (en/fr: camera, photos, speech, notifications, Face ID), encryption flag
- [ ] M10.2 Final app icon
- [ ] M10.3 Website: privacy, terms, support (Netlify)
- [ ] M10.4 Metadata en + fr (+ primary locale), screenshots, metadata workflow
- [ ] M10.5 Submit for review

## Not decided / later
- Monetization (free, or Pro with StoreKit 2)
- Cloud AI for hard receipts and Darija
- Dark mode, Arabic / Darija interface, Apple Watch app, widgets
