# Bztam — Roadmap

One task = one commit. Mark `[x]` when committed and CI is green. Progress is summarized in `REPORT.md`.

## Milestone 0 — Foundation
- [x] M0.1 README
- [x] M0.2 SPEC.md, ROADMAP.md, REPORT.md
- [x] M0.3 Xcode project via XcodeGen (`project.yml`): app `Bztam`, watch app `BztamWatch`, share extension `BztamShare`, unit and UI tests, iOS 26, App Group, placeholder screens and icons
- [x] M0.4 CI: build + test + screenshots on a macOS runner on every push
- [x] M0.5 TestFlight workflow (manual trigger and on tag): temporary signing via the API, archive, upload
- [x] M0.6 Setup guide for secrets and first TestFlight install (`docs/SETUP.md`)

## Milestone 1 — Core money (first TestFlight)
- [ ] M1.1 Design system: color tokens (light/dark), type styles, money formatting (MAD, en/fr)
- [ ] M1.2 L10n table (en/fr) with tests that every string exists and placeholders match
- [ ] M1.3 Data layer: SwiftData models (`Entry`, `Category`, `Settings`) in the App Group store, default categories
- [ ] M1.4 `BudgetCalculator` (periods from payday, in / spent / left, per category, not planned) + unit tests
- [ ] M1.5 Onboarding: payday, income, categories and budgets
- [ ] M1.6 Home screen and Liquid Glass tab bar shell
- [ ] M1.7 Add sheet: manual expense and income
- [ ] M1.8 Category detail; edit and delete entries with Undo
- [ ] M1.9 UI-test screenshots with demo data (en/fr); TestFlight build 1

## Milestone 2 — Scan receipts and screenshots
- [ ] M2.1 Attachment storage (compressed images in the App Group)
- [ ] M2.2 Camera: VisionKit document scanner
- [ ] M2.3 Text recognition service (Vision, fr/en)
- [ ] M2.4 `ReceiptParser` + unit tests with sample receipts and bills
- [ ] M2.5 Scan review screen
- [ ] M2.6 Screenshot import from Photos + "Add this screenshot?" prompt
- [ ] M2.7 TestFlight build 2

## Milestone 3 — Share extension and PDFs
- [ ] M3.1 Share extension (images and PDFs) → App Group inbox → review screen
- [ ] M3.2 PDF bills: PDFKit text, OCR fallback

## Milestone 4 — Activity, Insights, safety
- [ ] M4.1 Activity: entries by day, search, filters
- [ ] M4.2 Insights: donut by category, in vs out, vs previous period
- [ ] M4.3 Category alerts at 80% and 100%
- [ ] M4.4 Face ID lock
- [ ] M4.5 Settings screen

## Milestone 5 — Smart
- [ ] M5.1 Merchant → category memory
- [ ] M5.2 Foundation Models extraction and category guess when available
- [ ] M5.3 Duplicate warning

## Milestone 6 — Apple Watch
- [ ] M6.1 Summary payload from iPhone, glance screen
- [ ] M6.2 Quick add from the watch, synced to the iPhone

## Milestone 7 — App Store readiness
- [ ] M7.1 Privacy manifests, permission strings (en/fr), encryption flag
- [ ] M7.2 App icon (iPhone and watch)
- [ ] M7.3 Website: privacy, terms, support
- [ ] M7.4 Metadata en + fr (+ primary locale), screenshots, metadata workflow

## Later
- Monetization (when decided), iCloud sync, recurring entries, Siri / Shortcuts, export.
