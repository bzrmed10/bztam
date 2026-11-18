# Bztam — Progress report

Last updated: 2026-11-18 (evening)

## Status
Milestones 1–5 (core money, scanning, share extension and PDFs, Activity/Insights/alerts/lock/Settings, smart features) are built and CI is green. TestFlight is blocked by the App Store Connect API key (401).

## Done in Milestone 5
- Category memory: a shop goes to the category you chose for it last time (scan, Type it, Siri, typing the shop name)
- Apple Intelligence (on supported iPhones, on device) fills what the receipt rules missed; every value must appear in the receipt text, or it is thrown away
- Duplicate warning: same amount, same shop, same or next day → "Already added?"
- Type it: "taxi 20", "café 38", "khlst 50 f l9hwa", "+8000 salaire" fill the form (French, English, Darija in Latin letters)
- Say it: microphone in the Add sheet (on-device speech recognition, French or English)
- Siri / Shortcuts: "Add an expense in Bztam" asks the amount and what for, guesses the category
- Monthly recap on Insights (days left, biggest increase, mostly on weekends, biggest expense) and pace warnings ("At this pace, Going out runs out around 18 Nov") on Home and Insights
- Budget suggestions from the last 2–3 months in the categories editor ("Use all")
- Add sheet: top part scrolls, keypad and button stay at the bottom
- Tests: Type it phrases, memory, duplicates, AI safety net, pace, weekend share, suggestions

## Done in Milestone 4
- Activity: search by shop, note, category or amount; filter chips (All, Expenses, Money in, Category)
- Insights: donut by category with percentages, money in vs spent, comparison with the previous month and the categories that changed most; browse earlier months
- Budget alerts: a notification at 80% and at 100% of a category's budget, once per month (Settings toggle, on by default)
- Face ID / passcode lock when Bztam opens or comes back (Settings toggle, confirmed with Face ID)
- Settings: payday, currency (DH, €, $), categories editor (add, rename, icon, budget, planned first, reorder, archive), language (phone, English, Français) applied instantly, version
- Tests: Insights numbers, alert thresholds; demo data now has a previous month

## Done in Milestone 3
- "Share to Bztam" from any app (Photos, Mail, WhatsApp, Files, a biller's app): the image or PDF goes to the App Group inbox; Bztam opens the review screen the next time it opens
- PDF bills: embedded text read with PDFKit (first 3 pages), text recognition for scanned pages; first page shown as the preview and saved with the expense
- PDF button in the Add sheet (import from Files)
- Tests: a generated Lydec PDF is read as 310 DH, Lydec, Bills; CI screenshot of the PDF review

## Done in Milestone 2
- Camera scanning with Apple's document scanner (edges found, cropped, straightened)
- On-device text recognition (French and English), boxes grouped into lines
- Receipt reader for Moroccan receipts and bills: TOTAL TTC / NET À PAYER / Montant total, comma decimals, DH/MAD, day-first dates, known shops and billers (Marjane, Carrefour, BIM, Inwi, Orange, Maroc Telecom, Lydec, Redal, Glovo, Afriquia…) with a suggested category; 14 tests
- Scan review: image, total (tap to fix), shop, date, suggested category; Add expense or retake
- Screenshot import from Photos; optional "new screenshot looks like a bill" card on Home (Settings toggle, asks for photo access)
- Receipt images saved with the expense ("View receipt" when editing); unused images cleaned up
- Camera and photo permission texts in English and French
- CI screenshot of the review screen runs a sample receipt through the real text recognition: 245.50 DH, Marjane, 17 Nov, Groceries

## Done in Milestone 1
- Design system in SwiftUI (Wise-style tokens and components)
- English/French table with tests; money formatting (2,760 DH / 2 760 DH); keypad input in centimes
- SwiftData store in the App Group: entries, categories, settings; default categories
- BudgetCalculator with tests: payday periods, money in / spent / left, category left / over / paid, not planned
- Onboarding: payday, money in, plan your month
- Home: left to spend, quick actions, categories, previous periods
- Add sheet: expense and money in with keypad, chips, date and shop
- Category detail: left this period, entries, edit budget, add from the category
- Activity list by day; edit and delete with Undo everywhere
- Settings: payday, categories and budgets, privacy, version
- Demo month and UI-test screenshots (en/fr)

## Not yet working on purpose

## Blockers
- TestFlight: Apple answers 401 "credentials are missing or invalid" for the API key. Check the four repo secrets (see docs/SETUP.md, "If the TestFlight workflow fails").

## How to test
Once the secrets are fixed, run Actions -> TestFlight -> Run workflow, then install from the TestFlight app.

## Milestone 6: Recurring and planning
- Recurring rules (every week, month or year). Choose Repeat when adding an expense or money in. Entries are added automatically on their day when the app opens. Month-end dates are clamped (31 Jan → 28 Feb → 31 Mar).
- Settings → Recurring lists the rules with their next date. You can edit the amount, name, frequency and category, or stop repeating. Entries already added stay.
- Subscription detection: a shop paid at a similar amount in at least 3 of the last 4 months shows "Netflix every month?" on Home. Yes makes it a rule; Dismiss hides it for good.
- Move money: Category → Move money gives to or takes from another category for the current period only.
- Tests: RecurringTests (dates, month end, leap years, detection rules). CI is green and the screenshots are checked.
