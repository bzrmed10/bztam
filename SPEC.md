# Bztam — Product Spec (v1)

## Goal
Show clearly **where your money goes**: how much came in, how much went out, and how much is left in each category. Adding an expense takes under 5 seconds, including from a paper receipt, a screenshot or a PDF bill. Simple and minimal above everything.

## Platform and stack
- iOS 26+, iPhone only. Swift 6, SwiftUI, SwiftData, Swift Charts, Vision, VisionKit, PDFKit, Speech, App Intents, CloudKit, Foundation Models (when available).
- No backend, no accounts, no bank connection, no ads. All data on device (and in the user's own iCloud when sync is on) in a SwiftData store inside the App Group container, so the app and the share extension read the same data.
- Bundle IDs: app `com.bzrmed.bztam`, share extension `com.bzrmed.bztam.share`, App Group `group.com.bzrmed.bztam`.
- Languages: English and French (custom table, English text as key). Currency: Moroccan dirham (MAD, shown as "DH") by default, changeable.
- Apple Watch app and widgets: not in v1.
- Money (paid features): not decided. v1 is free. StoreKit 2 can be added later without a server.

## Core concepts
- **Entry**: one money movement. Kind = expense or income. Amount stored as whole centimes (`Int`), never `Double`. Date, merchant, note, category (expenses), income source (income), optional attachment (image or PDF file), source (manual, camera, screenshot, share).
- **Category**: name, SF Symbol icon, color, monthly budget (centimes), order, archived flag. Defaults: Courses, Café & Food, Transport, Bills, Phone & Internet, Rent, Going out, Other.
- **Period**: a budget month runs from the user's **payday** (day 1–28, default 1) to the day before the next payday.
- **Money in** for a period = sum of income entries. **Spent** = sum of expenses. **Left** = money in − spent.
- **Category left** = category budget − spent in that category. Money in not given to any category is shown as **Not planned yet**.
- All money math lives in a pure `BudgetCalculator` (no UI, no database) with unit tests.
- Attachments are compressed files in the App Group container; the database stores only the file name.
- The model stays CloudKit-friendly (default values, optional relationships, no unique constraints) so iCloud sync can be added later.

## Screens
Approved design: canvas "Bztam — App Design" (https://claude.ai/artifact/NNFw4ZfBJV3rLrcA1emD83) and design system "Bztam" (https://claude.ai/artifact/PvuhEkJngFfZbobmEfCF6B).
1. **Onboarding** (3 steps): payday; monthly income (optional); plan the month: categories with budgets (Rent, Bills, Phone planned first), "Not planned yet" shown live. Can be skipped.
2. **Home**: "Left to spend" hero number with period, money in and spent, progress bar; quick actions (Add, Scan, Screenshot, Money in); category list with icon circle, "X DH left" / "X DH over" / "Paid", "of" line and thin bar; "not planned" pill. Swipe to previous periods.
3. **Add sheet**: Expense / Money in switch; Scan receipt and Screenshot buttons; amount field with DH; category chips (or income source chips); date and shop/note; keypad; one primary button.
4. **Scan review**: receipt or PDF page with the total highlighted; "Total found" hero; shop, date, suggested category, all editable; Add expense / Retake photo.
5. **Category detail**: icon, "left this month" hero, spent of budget, bar, entries of the period; Edit budget.
6. **Activity**: entries grouped by day, search, filter chips (All, Expenses, Money in, Category). Swipe to delete with Undo; tap to edit.
7. **Insights**: where the money went (donut + legend), in vs out, comparison with the previous period, monthly recap text.
8. **Settings**: payday, currency, categories and budgets, recurring entries, Face ID lock, language, export, about, privacy.
Navigation: flat bottom tab bar (Home, Activity, Insights, Settings); the active tab has a lime pill.

## Receipts and bills
- **Camera**: VisionKit document scanner (auto edge detection and crop).
- **Screenshots**: Photos picker. When the app becomes active and the newest screenshot (last 10 minutes) looks like a bill, offer "Add this screenshot?".
- **Share to Bztam**: share extension accepting images and PDFs from any app. It saves the file into the App Group inbox; the app opens the review screen for it.
- **PDF**: embedded text via PDFKit; pages without text are rendered and sent through OCR.
- **Text recognition**: Vision on device (French, English).
- **Parser** (`ReceiptParser`, pure, unit-tested with sample texts): finds the total (TOTAL, TOTAL TTC, NET À PAYER, MONTANT, À PAYER, AMOUNT…), ignores subtotal/TVA lines, reads comma and dot decimals and thousands separators, dates in dd/mm/yyyy and similar, merchant from the first meaningful lines.
- The user always confirms. Nothing is saved silently.

## Smart features (AI)
Rule: **AI reads and explains; code does all the math.** Totals, balances and "left" are always computed by `BudgetCalculator`.
- **Better receipt reading**: on Apple Intelligence iPhones, Foundation Models extract total, date, merchant from the OCR text; rules work on every iPhone.
- **Category memory**: merchant → category learned from the user's choices; AI guesses unknown merchants.
- **Duplicate warning**: same amount, merchant and date (or same image) already added.
- **Type it**: "taxi 20", "café 38", "khlst 50 f l9hwa" → amount + category, ready to confirm (rules + on-device AI).
- **Say it**: dictation (Speech framework, fr/en) feeding the same parser. Siri / Shortcuts: "Add 20 DH taxi in Bztam" (App Intents).
- **Monthly recap**: plain-language summary of the period ("Café was 18% higher than October, mostly weekends").
- **Pace warnings**: "At this pace, Going out runs out around the 18th."
- **Budget suggestions**: after 2–3 periods, suggested amounts per category from real spending.
- **Ask Bztam**: questions like "How much did I spend on Glovo this month?" answered from computed numbers (the model calls Swift query functions; it never invents figures).
- Without Apple Intelligence the app works fully with rules; AI-only features are hidden.

## Recurring and planning
- Recurring entries: rent, salary, subscriptions, bills (monthly, weekly, yearly), added automatically on their day, editable once or for all.
- Subscription detection: repeated same merchant + amount suggested as recurring.
- Move money between categories within a period.

## Dart (tontine) tracker
- A dart: name, monthly amount, members (names only, no accounts), order of turns, start month.
- Each month: who has paid, whose turn it is to receive, reminder notifications.
- Paying into a dart can create an expense in a "Dart" category; receiving creates money in.

## Alerts and privacy
- Local notifications when a category reaches 80% and 100% of its budget (once per period per category).
- Optional Face ID / passcode lock when the app opens.
- Privacy manifest in every target; no tracking, no data collected.

## Data
- iCloud sync between the user's devices (SwiftData + CloudKit private database).
- Export CSV and PDF (period or all), with receipts optional.

## Design
Follows the design system "Bztam" (Wise-style):
- Flat white canvas, no cards or shadows; one soft green-grey surface for icon circles, inputs, chips.
- Big bold type (Inter / SF): 32pt screen titles, 48pt hero number, tabular figures.
- Colors: lime `#A6E36F` for the one main action per screen (always with forest text), forest `#14290B` for text and progress, green-grey `#EEF2EA` surface, positive `#2F7A2B` for money in, negative `#B3261E` for over budget (always with words).
- Pill buttons (56pt), pill chips, 48pt icon circles, 64pt rows, 24pt side margins.
- Haptics on save and delete; Undo toast after delete.
- Accessibility: Dynamic Type, VoiceOver labels on every control, 4.5:1 text contrast.

## Not decided / later
- Monetization (free, or a paid Pro with StoreKit 2).
- Cloud AI for hard receipts and Darija.
- Dark mode, Arabic / Darija interface, Apple Watch app, widgets.

## Out of scope
Bank sync, investments, crypto, shared budgets between people.
