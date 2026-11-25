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

## Milestone 14 — Ready for the App Store
- [x] M14.1 Cleaner "You're set" page (cards, switches inside, no scroll bar over the content), trimmed bill names, Add expense without a scroll bar over the form
- [x] M14.2 Send feedback (email to support@healus-ai.com with versions) and Restore from a backup (Bztam CSV, any language, skips duplicates)
- [x] M14.3 Accessibility: text follows the iPhone's text size (up to about +30%), 44 pt touch targets on Home, large-text screenshots
- [x] M14.4 App Store page: Arabic and en-GB texts, screenshots in Bztam's look (EN, FR, AR), metadata upload workflow
- [ ] M14.5 Upload texts and screenshots, TestFlight build, external testers

## Parked (decided 22 Nov)
- Automatic tracking (Apple Pay via Shortcuts Wallet automation, bank SMS, bank app notifications, review screen, duplicate matching). Parked: users may worry about "connecting" Apple Pay or their bank to an app, even though nothing leaves the phone. Notes kept: no API in Morocco (FinanceKit is US Apple Card only); iOS 27 can install a shared shortcut with its automation in ~3 taps; would be optional in Settings, never in onboarding.
- Idea to decide: import a bank statement PDF shared from the bank app (user-initiated, like sharing a bill; read on the phone, skips what's already there).

## Milestone 15 — Easier (design approved 23 Nov: canvas "Bztam: easier screens")
- [x] Plan tab (budgets, savings goals, every month, dart, friends); Settings shortened to settings only
- [x] Home: arrows around the dates, eye alone; 3 actions (Add, Scan, Import); one clear number per category ("90 DH left"); "without a budget"
- [x] Add expense: amount first; categories in one sideways row (suggested first); shop field; Today / Repeat / Split buttons that open small sheets; Type it with mic at the top; Scan and Import buttons at the top
- [x] Add expense keyboard: a "Back to keypad" button above the system keyboard (today the only ways back are the return key or dragging the list, which people don't find)
- [x] Check the receipt: one big button; Split smaller; Retake photo as a link
- [x] Plain words: "without a budget", "left over", "Move to another category"
- [x] Friends: small amounts you owe in normal text; Split options folded; onboarding bills card scrolls above the number pad

## ## M18 — Ready for the world, ready to sell (built 25 Nov)

### More currencies
- [x] About 30 currencies with local symbols and writing (DA, DT, FCFA after the number…): Maghreb (DZD, TND, LYD), Europe (EUR, GBP, CHF, SEK, NOK, DKK, PLN, TRY), Gulf and Middle East (SAR, AED, QAR, KWD, BHD, OMR, JOD, EGP), Africa (XOF, XAF, NGN), Americas (USD, CAD, BRL, MXN), Asia (INR, MYR, JPY).
- [x] Onboarding: the iPhone's region currency at the top (detection already exists, but only for the 8 current currencies; others fall back to DH), plus a search field.
- [x] Currencies without cents (FCFA, yen): no decimals, no comma on the keypad. 3-decimal dinars keep 2 decimals.
- [x] Keypad: more digits for big currencies (FCFA, naira salaries).
- [x] Fixed limits made for dirhams scale per currency (rough size vs DH): Advice step 50 / gap 100, InsightsCalculator minimum 50, Recap 200 and 50. Amounts are never converted.

### Moroccans abroad
- [x] A "Sent to family" category; euros suggested for European regions.

### Add a category from where you pick one
- [x] A "+" at the end of the sideways category chips (Add/Edit expense, Move sheet) and a "+ Add a category" row at the end of the categories on Home. Opens the new-category sheet; the new category is selected right away.

### Bztam Plus (pricing decided 24 Nov)
- [x] Yearly ~9.99 $ and Lifetime ~24.99 $ (lifetime shown as the main choice: "Pay once. Yours forever."). Morocco/Maghreb ~49 DH and ~129 DH (per-country prices in App Store Connect). No monthly plan.
- [x] 14-day free trial: a free non-consumable "14-Day Trial" (never charges), like Inly. No paywall at launch.
- [x] Free: budget, categories, expenses, Home, Activity, calendar, month-end card, 1 savings goal, dart, splitting, Face ID lock, privacy mode, iCloud sync, notifications, widgets, Siri.
- [x] Plus: unlimited savings goals, receipt scanning and PDF bill import, automatic month-end choices, export and backup files, later big features (shared budget…).
- [x] Plus offered only at moments of value (2nd goal, first scan, automatic month end, export). Paywall: price, period, renewal terms, Restore purchases, Redeem code, Terms of Use + Privacy links.
- [x] TestFlight-only "Test as free user" switch.
- [ ] User: create the 2 products (+ trial) in App Store Connect, prices per country, Family Sharing on lifetime.

### Face ID
- [x] Fixed (25 Nov): Face ID was asked while the app was still opening, so iOS went straight to the passcode. Now asked once the app is on screen; if Face ID is turned off for Bztam, the lock screen says so with a link to Settings.

Product IDs: com.bzrmed.bztam.plus.lifetime (non-consumable, Family Sharing on), com.bzrmed.bztam.plus.yearly (auto-renewable, group "Bztam Plus", 1 year), com.bzrmed.bztam.plus.trial (non-consumable, free). Paywall screenshot for review: en-40-plus.png (-paywallShot).

## Fixes from TestFlight (done 25 Nov)
- [x] Settings: a Bztam Plus card at the top. Free: "Try Bztam Plus" with the main benefits, opens the Plus screen. Plus: "Bztam Plus · Lifetime" (or Yearly / Trial, N days left), and Manage subscription for Yearly. Remove the small row from the App section.
- [x] Currency list (onboarding and Settings): the selected row's border is cut at the edges, and the scroll bar runs over the rows. Draw the border inside the row (strokeBorder), give the list a little side padding, hide the scroll bar.
- [x] Your fixed bills grid: same problem (selected tile border cut on the right, scroll bar over the tiles). Same fix.
- [x] Saving step and goal editor: the "By a date" toggle looks cut on the right. Give it room (no clipping, normal toggle size).
- [x] Check every list and grid with a selected border for the same clipping (categories, Move sheet, goal picker, month-end picker).
- Note: "Test as free user" only appears in TestFlight builds; App Store users never see it.

## Next — Ask Bztam in Plus (decided 25 Nov, to build)
- [ ] Free users: 3 questions a month (counted per calendar month, on the device); the 4th opens the Plus screen (new reason "ask"). Plus: unlimited.
- [ ] Same on every iPhone, with or without Apple Intelligence (the paid value never depends on Apple's model).
- [ ] Plus screen: a 5th benefit "Ask anything about your money". Ask screen shows "2 free questions left this month" for free users.
- [ ] Review notes: "Ask Bztam answers with the app's own engine on the user's data; it works on devices without Apple Intelligence, which only helps understand wording when available."
- [ ] If App Review rejects it under 4.10: make Ask free again and resubmit.

### Ask Bztam: answer more (Bztam's engine computes; Apple's model only helps understand the question; no outside AI, nothing leaves the phone)
- [ ] 1. Comparisons: "Did I spend more than last month?" → both periods, the difference and %.
- [ ] 2. A named month or dates: "in October", "between the 1st and the 10th", "in March 2026".
- [ ] 3. Several categories together: "food and transport", "everything except rent".
- [ ] 4. Goals, dart and recurring bills: saved for a goal and what's left to reach it, next dart turn and who's next, what's due this month.
- [ ] 5. Facts-based "can I…" and "will I…": "Can I afford a 3,000 DH phone?" → compares with left to spend and goals; "Will I finish the month?" → today's pace vs what's left. Numbers only, never financial advice.
- [ ] 6. Follow-ups: "And last month?", "And at Marjane?" reuse the previous question and change one part.
- [ ] 7. Income by source: "How much from freelance?" (salary, freelance, side job…).
- [ ] 8. Unusual wording without Apple Intelligence: more words in the lists (EN/FR/AR/Darija), and when unsure, suggest the closest questions to tap.
- [ ] Apple's model: new fields to fill (compare, month/dates, several categories, goal/dart, follow-up, income source) so it recognises these on iPhones that have it.
- [ ] Tests for each new kind of question in the 4 languages.


## App Review rules — check before every submission (from Inly's rejection, 24 Nov)
- **2.3.7 Accurate metadata:** no price words anywhere in screenshots, name, subtitle, keywords or promotional text: no "free", "gratuit", "مجاني", "no subscription", "pay once", "lifetime", discounts or prices. Captions describe what the app does, nothing about cost. (Checked 25 Nov: current texts and screenshots are clean.)
- **4.10 Built-in capabilities:** never charge for iCloud sync, Face ID lock, notifications, widgets, Siri, or camera/photo access. Ask Bztam in Plus is a deliberate try (own engine, works without Apple Intelligence); free again if rejected. Plus only sells Bztam's own work (unlimited goals, scanning that reads receipts, automatic choices, exports).
- **3.1.1 / 3.1.2 In-app purchase:** only Apple IAP; Restore purchases; the subscription screen shows price, length, auto-renew and links to Terms of Use (EULA) and Privacy; the Terms link is also in the App Store description or as the custom EULA.
- **2.1 Completeness:** no login; everything works for the reviewer; IAPs submitted with the version (Add for Review → the draft); review notes explain scanning, dart and where Plus appears.
- **5.1.1 Privacy:** "Data Not Collected"; privacy policy URL live; every permission asked only when used, with a clear reason; nothing breaks if a permission is refused.
- **2.3.3 / 2.3.10 Screenshots:** show the real app in use; no other platforms (Android) or competitors named.
- **Health of the build:** no crash on launch for a fresh install, iPad not targeted (iPhone only), all links in Settings work.

M17 — When the month ends (24 Nov, mockups: canvas row "When the month ends")
- [x] Card on Home the first days after payday: "You have 640 DH left" → Add to next month (big), Add to savings, Leave it; "Later" hides it for a day.
- [x] Went over: "You went 300 DH over · It happens." → Take it from next month, From a goal, Leave it.
- [x] Several goals: a sheet to pick one, with each goal's progress after the money.
- [x] After a choice: a note with Undo for 3 days; "+640 DH from last month" under Left to spend.
- [x] Payday notification "Your month is done" (Alerts → Month done).
- [x] Settings → When the month ends: Ask me / Add to next month / Add to savings / Leave it (automatic only when money is left).
- [x] Insights → Past months: how each month ended and where the money went.
- [x] Widget: "+640 DH from last month" the first days.
- [x] CloudKit schema deployed to Production (24 Nov): Development and Production match.

M16 — Small fixes and the spending calendar (done 24 Nov)
- [x] Category management is hard to find since the Plan tab: add a clear "Categories" row in Plan (add, rename, reorder, archive), not only behind the Budgets card.
- [x] "Move to another category" is too long for the category screen button: use "Move" (keep the full sentence as the sheet's subtitle).
- [x] Date sheet in Add/Edit expense opens half-way, so its "Date" title and "Done" are hidden: open it fully, or put Done where it is always visible.
- [x] Move sheet still has the old design: categories in one sideways row like Add expense, amount big in the middle.
- [x] Category screen: no icon on the rows (all the same category); the category icon sits small next to the name at the top; "730 DH left" big under it; split rows say "split with 3 friends". Mockup: canvas "Bztam: easier screens", artboard Category.
- [x] Spending calendar (idea, 24 Nov, mockup: canvas artboard Calendar): calendar button next to the eye on Home, also as a calendar button in the Activity header. Month grid with what was spent each day, lime shades for more or less (no category colors), month total and daily average; tap a day to see its expenses. Decided: privacy keeps the dots.
