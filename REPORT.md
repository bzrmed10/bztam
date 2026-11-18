# Bztam — Progress report

Last updated: 2026-11-18 (evening)

## Status
Milestones 1 (core money), 2 (scan receipts and screenshots) and 3 (share extension and PDF bills) are built and CI is green. TestFlight is blocked by the App Store Connect API key (401).

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
- Insights is a placeholder (Milestone 4)

## Blockers
- TestFlight: Apple answers 401 "credentials are missing or invalid" for the API key. Check the four repo secrets (see docs/SETUP.md, "If the TestFlight workflow fails").

## How to test
Once the secrets are fixed, run Actions -> TestFlight -> Run workflow, then install from the TestFlight app.
