# Setup guide

## One-time setup
1. **GitHub repo secrets** (Settings -> Secrets and variables -> Actions). The same values as Inly work:
   - `APPLE_TEAM_ID` - 10-character Team ID
   - `ASC_KEY_ID` - App Store Connect API key ID (key role must be **Admin**)
   - `ASC_ISSUER_ID` - issuer ID
   - `ASC_KEY_P8` - full contents of the `.p8` file, including the BEGIN/END lines
2. **App Store Connect**: app "Bztam" with bundle ID `com.bzrmed.bztam` (Apps -> + -> New App). Note its primary language.
3. **App Group** (needed before the first TestFlight build):
   - developer.apple.com -> Certificates, Identifiers & Profiles -> Identifiers -> **+** -> App Groups -> `group.com.bzrmed.bztam`.
   - The first TestFlight run registers `com.bzrmed.bztam.share` and `com.bzrmed.bztam.watchkitapp` and turns on the App Groups capability for the app and the share extension.
   - Then open the identifiers `com.bzrmed.bztam` and `com.bzrmed.bztam.share`, App Groups -> **Configure** -> tick `group.com.bzrmed.bztam` -> Save. The API cannot do this step. Run the TestFlight workflow again afterwards.

## Getting a build on your iPhone
1. GitHub -> **Actions** -> **TestFlight** -> **Run workflow** (branch `main`). Takes about 10-20 minutes.
2. App Store Connect -> **Apps** -> Bztam -> **TestFlight**. The build appears after processing (a few more minutes).
3. First time only: **Internal Testing** -> **+** -> create a group, add yourself, enable the build for the group.
4. On your iPhone, open **TestFlight**, then Bztam -> Install. The watch app installs from the Watch app on the iPhone (or automatically if that setting is on).
5. Later builds: run the workflow again; each run gets a new build number automatically.

## How signing works (no Mac, no registered device)
Each TestFlight run (`scripts/ci/asc_signing.py`) creates a temporary Apple Distribution certificate and three App Store provisioning profiles (app, share extension, watch app) through the App Store Connect API, signs, and uploads. The certificate is kept until the next run so Apple can finish processing, then revoked at the start of the next run.

**Important:** Inly and Bztam share the same Apple team. Each run revokes the previous distribution certificate, whichever app created it. Do not run the Inly and Bztam TestFlight workflows at the same time, and wait until the other app's build shows "Ready to test" before starting one.

## If the TestFlight workflow fails
- **"Missing repository secret"**: add the secret named in the error.
- **API errors 401/403**: the API key role is too low or the key was revoked. Use a key with the **Admin** role.
- **App Group or entitlement errors**: do step 3 above (tick the App Group on both identifiers), then run again.
- **Build uploaded but not visible**: wait for processing, and check your email for a notice from App Store Connect.
- **"90721 Certificate Revoked"**: another TestFlight run (Inly or Bztam) started while this build was processing. Run the workflow again.
- Logs from each run are attached as the `testflight-logs` artifact.

## CI
Every push to `main` builds the app, the share extension and the watch app, runs the unit tests and takes screenshots. Screenshots are pushed to the `ci-screenshots` branch and attached to the run.
