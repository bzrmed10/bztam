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
- [x] M6.1 Recurring entries (rent, salary, subscriptions, bills): model, auto-add on their day, edit once or all
- [x] M6.2 Subscription detection → "Make this recurring?"
- [x] M6.3 Move money between categories
- [ ] M6.4 TestFlight build 6 (waiting for the API key secrets and App Group)

## Milestone 7 — Ask Bztam → TestFlight 7
- [x] M7.1 Query functions over entries (by merchant, category, period, kind) + tests
- [x] M7.2 Ask screen: questions answered by the on-device model calling those functions; numbers always from code
- [ ] M7.3 TestFlight build 7 (waiting for the API key secrets and App Group)

## Milestone 8 — Dart (tontine) tracker → TestFlight 8
- [x] M8.1 Dart model: members, monthly amount, turn order, start month
- [x] M8.2 Dart screens: list, detail (this month: who paid, whose turn), create/edit
- [x] M8.3 Link to money: paying creates an expense, receiving creates money in
- [x] M8.4 Reminders (local notifications)
- [ ] M8.5 TestFlight build 8 (waiting for the API key secrets and App Group)

## Milestone 9 — Data → TestFlight 9
- [x] M9.1 iCloud sync (SwiftData + CloudKit private database)
- [x] M9.2 Export CSV and PDF (period or all)
- [ ] M9.3 TestFlight build 9 (waiting for the API key secrets, App Group and iCloud container)

## Milestone 10 — App Store readiness
- [x] M10.1 Dark mode (Settings → Appearance: Automatic, Light, Dark)
- [x] M10.2 Final app icon (Wallet, with dark and tinted versions)
- [x] M10.3 Privacy manifests, permission strings (en/fr), encryption flag
- [x] M10.4 iCloud schema file + workflow + sync status in Settings (needs CK_MANAGEMENT_TOKEN, then Deploy in CloudKit Console)
- [x] M10.5 Website: home, privacy, terms, support, en + fr (needs Netlify + support email)
- [x] M10.6 App Store texts en + fr
- [ ] M10.7 Framed store screenshots + metadata upload workflow
- [ ] M10.8 TestFlight build 6, then submit for review

## Not decided / later
- Monetization (free, or Pro with StoreKit 2)
- Cloud AI for hard receipts and Darija
- Darija interface, Apple Watch app (not planned)

## Milestone 11 — Split with friends
- [x] M11.1 Friends list, equal split from a ticket or the Add sheet, bank-style counting (paybacks come back into the category)
- [x] M11.2 Balances (Home card, Friends screen), paying back in full or in part, forget, WhatsApp messages, reminders
- [x] M11.3 Ask Bztam "who owes me", iCloud schema, website section, App Store texts
- [x] M11.4 Deploy Schema Changes in CloudKit Console

## Milestone 12 — Polish, widgets, Arabic
- [x] M12.1 Privacy mode (eye on Home, hide on open, hide only money in, app-switcher cover), new currencies (EUR, USD, GBP, CAD, CHF, SAR, AED)
- [x] M12.2 "For you" row on Home, status bar fade, empty states with an action
- [x] M12.3 Animations (added toast with undo, filling bars, number roll, zoom into categories, scanning line)
- [x] M12.4 New onboarding with a suggested budget plan (BudgetPlanner)
- [x] M12.5 Weekly recap and unusual spending alerts
- [x] M12.6 Widgets (Home and Lock Screen), Control Center and Action button controls
- [x] M12.7 Arabic interface (right to left)
- [x] M12.8 Website (Arabic site, widgets section, new features), App Store texts
- [x] M12.9 TestFlight build

## Milestone 13 — Onboarding, savings goals, Siri
- [x] M13.1 Keyboard: Done button above number pads; Add expense hides its keypad while typing and shows "More below"
- [x] M13.2 Savings goals (put aside / take out, saved lowers what's left, Home section and card, Settings)
- [x] M13.3 New onboarding: currency, payday, salary (recurring), other income, household, bills grid with your own, recurring bills with their day, lifestyle, savings and a first goal, plan bar with leftover choice, summary. Every step skippable; "Set up your month" card and "Plan my month again"
- [x] M13.4 Siri: "Add to Bztam" → "taxi 20", "What's left in Bztam", Undo under the answer; phrases in 3 languages
- [x] M13.5 Website, App Store texts, iCloud schema (SavingsGoal, GoalMove)
- [x] M13.6 TestFlight build (Deploy Schema Changes in CloudKit Console: user)

## Next milestone — to do (noted 22 Nov, from TestFlight)
- [ ] Onboarding "You're set" page: redesign to be cleaner. The scroll bar runs into the list area and the "Already paid this month" switches are cut off on the right. Idea: one card per bill with the switch inside the card, no visible scroll bar, the list inset from the edges.
- [ ] Trim spaces in bill names you type ("iCloud " showed as "iCloud  ·").
- [ ] Add expense: same scroll fix as the summary page. The scroll bar shows over the form; hide it and keep the content inset so nothing touches the edge.

## Parked (decided 22 Nov)
- Automatic tracking (Apple Pay via Shortcuts Wallet automation, bank SMS, bank app notifications, review screen, duplicate matching). Parked: users may worry about "connecting" Apple Pay or their bank to an app, even though nothing leaves the phone. Notes kept: no API in Morocco (FinanceKit is US Apple Card only); iOS 27 can install a shared shortcut with its automation in ~3 taps; would be optional in Settings, never in onboarding.
- Idea to decide: import a bank statement PDF shared from the bank app (user-initiated, like sharing a bill; read on the phone, skips what's already there).
