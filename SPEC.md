# Bztam — Product Spec (v1)

## Goal
Show clearly **where your money goes**: how much came in, how much went out, and how much is left in each category. Adding an expense takes under 5 seconds, including from a paper receipt, a screenshot or a PDF bill. Simple and minimal above everything.

## Platform and stack
- iOS 26+, iPhone only. Swift 6, SwiftUI, SwiftData, Swift Charts, Vision, VisionKit, PDFKit, Foundation Models (when available).
- No backend, no accounts, no bank connection, no ads. All data on device in a SwiftData store inside the App Group container, so the app and the share extension read the same data.
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
1. **Onboarding** (3 steps): payday; monthly income (optional); categories with budgets (suggested split, Rent and Bills planned first). Can be skipped.
2. **Home**: month header (swipe to previous months); summary In / Spent / Left; list of categories with a progress bar and "X DH left" (coral when over); "Not planned yet" row when relevant; floating **+** button.
3. **Add sheet**: Expense / Income switch; big amount field with decimal keypad; category chips (or income source chips); date (today by default); merchant and note (optional). Top row: **Camera** and **Photos** buttons. Saves in one tap.
4. **Scan review**: the image (or PDF page) with the detected total, date, merchant and suggested category, all editable. Confirm saves the entry with the attachment.
5. **Category detail**: spent vs budget, entries of the period, edit budget.
6. **Activity**: all entries grouped by day, search (merchant, note, amount), filter by category and kind. Swipe to delete with Undo; tap to edit.
7. **Insights**: where the money went (donut by category), money in vs out, comparison with the previous period.
8. **Settings**: payday, currency, categories and budgets, Face ID lock, language, about, privacy.
Navigation: iOS 26 Liquid Glass tab bar (Home, Activity, Insights) and a glass Settings button.

## Receipts and bills
- **Camera**: VisionKit document scanner (auto edge detection and crop).
- **Screenshots**: Photos picker. When the app becomes active and the newest screenshot (last 10 minutes) looks like a bill, offer "Add this screenshot?".
- **Share to Bztam**: share extension accepting images and PDFs from any app. It saves the file into the App Group inbox; the app opens the review screen for it.
- **PDF**: embedded text via PDFKit; pages without text are rendered and sent through OCR.
- **Text recognition**: Vision on device (French, English).
- **Parser** (`ReceiptParser`, pure, unit-tested with sample texts): finds the total (TOTAL, TOTAL TTC, NET À PAYER, MONTANT, À PAYER, AMOUNT…), ignores subtotal/TVA lines, reads comma and dot decimals and thousands separators, dates in dd/mm/yyyy and similar, merchant from the first meaningful lines.
- **On-device AI**: on Apple Intelligence iPhones, Foundation Models improve extraction and the category guess. Rules work on every iPhone.
- **Category memory**: merchant → category learned from the user's choices.
- The user always confirms. Nothing is saved silently.
- No cloud AI in v1.

## Alerts and privacy
- Local notifications when a category reaches 80% and 100% of its budget (once per period per category).
- Optional Face ID / passcode lock when the app opens.
- Privacy manifest in every target; no tracking, no data collected.

## Design
- Minimal: lots of space, one number at a time, rounded system type.
- Colors: warm terracotta accent, green for money in, coral for over budget, quiet greys. Light and dark mode.
- Haptics on save and delete; Undo toast after delete.
- Accessibility: Dynamic Type, VoiceOver labels on every control, sufficient contrast.

## Out of scope for v1
Bank sync, investments, crypto, shared budgets, recurring entries, iCloud sync, cloud AI, widgets, Apple Watch app.
