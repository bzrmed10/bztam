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

## Milestone 7: Ask Bztam
- Insights → "Ask about your money" opens Ask Bztam. Type or say a question in English, French or Darija (Latin letters).
- Understands: how much spent, money in, what's left (overall or per category), how many times, biggest expense, where most money went; for this or last period, this or last week, today, yesterday, this year, or since the start; filtered by a category or a shop you've paid.
- Keyword rules answer first. When Apple Intelligence is on, the on-device model only fills what the rules missed, and every value it returns is checked. The model never sees or writes numbers: all amounts come from `AskEngine`.
- Each answer shows how the question was understood (chips) and the entries behind it.
- Tests: AskTests (parsing in three languages, every answer type, model merge checks). CI is green and the screenshots are checked.

## Milestone 8: Dart (tontine)
- Settings → Dart: create a dart with a name, what each person pays a month, the first turn date, and the members in turn order (you included, moved with up/down).
- Detail: the pot per turn, this turn (who collects, tick who paid), your totals (paid so far, your turn date or what you collected), and every turn with its date.
- Ticking yourself adds an expense in the category you chose; on your turn, "I collected" adds the pot as money in. Unticking removes it. This can be turned off per dart.
- Home shows a card when you owe this turn ("Pay 1,000 DH for Family") or when it's your turn to collect, with a one-tap button.
- Reminders: a notification at 9:00 on the next turn days, rescheduled when the app opens or a dart changes.
- Dart payments are left out of subscription detection.
- Tests: DartTests (turn dates with month ends, status over time, payments and totals, reminder dates). CI is green and the screenshots are checked.

## Milestone 9: Data
- iCloud sync (Settings → Data, on by default): the store is mirrored to your private iCloud (CloudKit). Apple keeps it; Bztam has no server. Turning it on or off applies the next time Bztam opens. Receipt photos stay on the iPhone that took them.
- A second iPhone makes its own settings and default categories before iCloud data arrives, and two iPhones can both add the same recurring entry. Bztam folds these together after each sync (one settings row, one category per built-in key with all entries moved onto it, one recurring entry per rule and day).
- Export (Settings → Data → Export): a PDF report (totals, categories against budgets, every entry) or a CSV (semicolons and decimal commas in French, commas and points in English, opens correctly in Excel) for this period, last period, this year or everything, shared with the system share sheet.
- Signing: the TestFlight workflow now turns on iCloud and Push Notifications for the app ID. Creating the iCloud container and ticking it is a one-time manual step (docs/SETUP.md, step 4).
- Tests: ExportTests (CSV in both formats, decimals, quoting, file names, multi-page PDF) and CloudMergeTests (merging on an in-memory store). CI is green and the screenshots are checked.

## Milestone 12: Polish, widgets, Arabic
- Privacy mode: the eye on Home hides amounts as "••••". Settings → Privacy can hide them each time Bztam opens, or hide only money in (salary, money left, insights). The app switcher shows a cover instead of your numbers. Widgets follow the same settings.
- Currencies: dirham, euro, dollar, pound, Canadian dollar, Swiss franc, Saudi riyal, UAE dirham. In English, €, $, £ go before the number.
- Home: a "For you" row pages through the cards (screenshot, subscription, friends, dart, unusual spending, weekly recap, pace). A soft fade under the status bar on long pages. Empty lists show a small illustration and an action. No category colors, as decided.
- Animations: an "Added" toast with undo and a haptic, bars that fill in, the money left rolls when it changes, categories zoom open, a scanning line while reading a receipt, a pulsing microphone.
- Onboarding: a short tour, then payday, income, fixed bills and three lifestyle questions. `BudgetPlanner` suggests budgets and savings that fit the income; "Just track first" keeps only the bills.
- Weekly recap (Monday 9:00 notification and Home card) and unusual spending: a category well above the same days of the last 3 periods, or a bill well above its usual amount.
- Widgets: Left to spend (small, medium, Lock Screen). Controls "Add expense" and "Scan receipt" for Control Center, Lock Screen and the Action button.
- Arabic: the whole interface (495 strings) right to left, Arabic speech recognition, Arabic questions in Ask Bztam. Amounts stay as one left-to-right piece inside Arabic sentences.
- Website: an Arabic site (bztam/ar), a widgets section, privacy mode, recap and alerts, languages. App Store texts updated.
- Tests: BudgetPlannerTests, RecapTests, currency placement, Arabic coverage and placeholders.
