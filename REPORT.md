# Bztam — Progress report

Last updated: 2026-11-17

## Status
Milestone 0 (foundation) complete in code. Waiting for the first TestFlight run.

## Done
- M0.1 README, repo connected, push access verified
- M0.2 SPEC.md, ROADMAP.md, REPORT.md
- M0.3 Xcode project (XcodeGen): app, share extension, watch app, unit and UI tests, App Group, placeholder screens and icons
- M0.4 CI: build, unit tests, iPhone and watch screenshots on every push. First run: green.
- M0.5 TestFlight workflow (manual or on tag): temporary signing via the App Store Connect API, archive, upload. Not run yet.
- M0.6 Setup guide in `docs/SETUP.md`

## Next
- First TestFlight run (needs secrets, the App Store Connect app record and the App Group, see `docs/SETUP.md`)
- Milestone 1: core money (design system, data, budget math, onboarding, Home, add entries)

## Blockers
None in code. The App Group must be created and ticked on the identifiers by hand (see `docs/SETUP.md`).

## How to test
Builds are uploaded to TestFlight at the end of each milestone. Install the TestFlight app on your iPhone and accept the invite for `Bztam`.
