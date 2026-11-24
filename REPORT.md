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
- Delete all data (Settings → Data): asks to confirm (and Face ID when the lock is on), deletes everything here and in iCloud, removes receipt photos and reminders, then shows onboarding again. Language, currency and appearance stay.
- Website language: one globe button opens English, Français, العربية, each going to the same page.
- Tests: BudgetPlannerTests, RecapTests, ResetDataTests, currency placement, Arabic coverage and placeholders.

## Milestone 13: Onboarding, savings goals, Siri
- Onboarding: welcome, currency (from the iPhone's region, saved only when you continue), payday, salary on the keypad with "Same amount every month" (a recurring income on payday) and other regular income, household (just me, two, family with adults and children), fixed bills (12 common ones plus your own, each with an amount, its day and "Same every month"), cafés and transport, savings with an optional first goal, then the plan and a summary.
- Every step has Skip; the welcome has "Skip setup, I'll look around". Skipping everything opens the app with the default categories and a "Set up your month" card on Home. Settings → "Plan my month again" reruns it without the welcome and keeps existing data.
- Plan: groceries follow the household (12% for one person, +5% per extra adult, +4% per child, at most 35%), a transport pass comes on top of transport, loans/school/insurance/sport/subscriptions/family help/home help get their own fixed category when picked. A bar shows bills, everyday, savings and what's free; money nobody claimed can stay as a cushion, go to savings or be shared out. Every amount shows the currency and can be edited.
- Bills with the same amount every month become recurring expenses on their day. If the day already passed this month, the summary asks "Already paid this month" (on: added now, off: starts next month). Water and electricity default to a budget only.
- Savings goals: name, icon, optional target and date, monthly plan ("750 DH a month gets you there"). Put aside / take out with the keypad; money put aside lowers what's left to spend and shows as "saved" on Home, never as spending. Goals on Home and in Settings, a "Put 750 DH aside" card, a message when a goal is reached.
- Siri, without opening the app: "Add to Bztam" → "taxi 20" (category guessed like in the app, Undo button under the answer), "What's left in Bztam", "Scan a receipt with Bztam". "Add an expense" with an amount and what for is also available to Shortcuts.
- Keyboard: a floating Done button above number pads in onboarding, goals, categories, splits, darts and recurring. Add expense hides its keypad while the keyboard is open and shows "More below" when the form continues under it.
- iCloud schema: two new record types, SavingsGoal and GoalMove (deploy to Production after testing).
- Tests: GoalTests, OnboardingSetupTests, new planner tests (household, transport pass, leftover).

## Milestone 14: Ready for the App Store
- "You're set" page: three cards (your month, added every month, your plan) plus reminders; the "Already paid this month" switch sits inside its card; no scroll bar over the content. Names you type are trimmed. Add expense hides its scroll bar ("More below" shows when the form continues).
- Settings → App → Send feedback: an email to support@healus-ai.com with the app version, iOS version and language filled in.
- Settings → Data → Restore from a backup: picks a CSV exported from Bztam (English, French or Arabic, "," or ";"), shows how many entries are new, adds them and skips the ones already there. Categories are matched by name in any language, or created.
- Text size: every font follows Settings → Display → Text Size, from a little smaller to about 30% larger (capped so layouts stay clean). Home's eye and period arrows are 44 pt touch targets. New large-text screenshots.
- Website: support@, privacy@ and legal@healus-ai.com on the matching pages.
- App Store: en-GB (the app's primary language), en-US, fr-FR and ar-SA texts; screenshots made by scripts/appstore/compose.py from the CI captures, in Bztam's lime and forest look, 8 per language (7 in Arabic until the goals capture lands); `App Store metadata` workflow uploads texts and screenshots (check mode prints what App Store Connect holds).
- Tests: BackupImportTests (round trip in 3 languages, duplicates, other files), testLargeText, testBillsSkipAndRemove.

## Milestone 15: Easier
- Plan tab (5 tabs: Home, Activity, Plan, Insights, Settings): budgets (planned of income, without a budget), savings goals, Every month, Dart, Friends, Plan my month again. Settings keeps only settings: your month, privacy, alerts, receipts, data, app.
- Home: period arrows around the dates, the eye on its own; three wide actions (Add, Scan, Import → screenshot or PDF); each category shows one number ("90 DH left", "40 DH over", "Paid") with "310 of 400 DH spent" under the bar; "without a budget".
- Add expense: Scan and Import at the top, Type it with the mic, the amount big in the middle, categories in one sideways row (most used first; the picked one scrolls into view), shop or note, then Today / Repeat / Split side by side (Today opens a small date sheet with Today and Yesterday). When the system keyboard is up, a "Keypad" button brings the number keypad back.
- Check the receipt: one big Add expense button; Split with friends small; Retake photo as a link.
- Words: "left over", "Move to another category". Friends: what you owe a friend in normal text (red only for the total). Split: Include me / Remind me folded under Options. Onboarding: a picked bill scrolls into view.

## M16 — Small fixes and the spending calendar (24 Nov 2026)
- Plan: a "Categories" row (add, rename, reorder, hide).
- Category screen: "Move" button; icon small next to the name; big "left" amount with days to go; rows without repeated icons; split rows say "Split with friends".
- Move sheet: big amount in the middle, categories in one sideways row.
- Add/Edit expense: the date sheet opens fully, so Date and Done are visible.
- Spending calendar (Home, next to the eye, and in Activity): month grid with what was spent each day in lime shades, month total, daily average, days with nothing spent; tap a day for its expenses. Refunds from friends count back. Amounts rounded to whole units.
- Tests: SpendingCalendarTests (daily totals, levels, grid start, rounding). Screenshot 36-calendar.

## M17 — When the month ends (24 Nov 2026)
- New model MonthClose (one decision per ended month; latest wins across iPhones). CloudKit schema updated and imported to Development.
- Carry-over is not an entry: PeriodSummary has carriedIn/carriedOut, so Insights never counts it as income. Saving to a goal is a GoalMove on the month's last moment, so the ended month closes at zero.
- Card asked only when the app was used before that month ended, money came in that month, nothing decided yet, within 10 days of payday.
- Undo removes the decision (and the goal move); the card comes back.
- Settings: When the month ends (automatic choice for months with money left); Alerts: Month done (monthly notification on payday at 10:00).
- Insights: Past months (last 6). Widget subtitle shows the carried amount the first 5 days.
- Tests: MonthEndTests (carry, overspend, latest wins, pending rules, history). Screenshots 37-monthend, 38-monthover, 39-monthend-pick.
