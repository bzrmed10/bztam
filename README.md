# Bztam

Bztam (بزطام, "wallet" in Darija) is a simple, minimal money app for iPhone. It shows where your money goes: how much came in, how much you spent and how much is left in each category. Snap a receipt, pick a screenshot or share a PDF bill and it becomes an expense.

- Swift 6, SwiftUI, SwiftData, Swift Charts, Vision / VisionKit, PDFKit
- Minimum iOS: 26 (iPhone only)
- Languages: English, French
- Bundle ID: `com.bzrmed.bztam` (share extension: `com.bzrmed.bztam.share`, App Group: `group.com.bzrmed.bztam`)
- No backend, no account, no bank connection. Data stays on the device.

The Xcode project is generated with XcodeGen (`project.yml`). GitHub Actions builds, tests, takes screenshots and uploads to TestFlight. No Mac needed.

See `SPEC.md` for the product spec, `ROADMAP.md` for the task list, `REPORT.md` for progress and `docs/SETUP.md` for secrets and TestFlight.
