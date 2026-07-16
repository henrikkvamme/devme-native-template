# Xcode Cloud and TestFlight

Xcode Cloud owns iOS archive signing, build numbers, App Store Connect processing, and internal TestFlight distribution. The repository supplies the shared `Starter` scheme and an archive guard in `apps/ios/ci_scripts`.

## Before Xcode Cloud

1. Rename `Starter`, replace its bundle identifiers, and select your Apple Developer team in Signing & Capabilities.
2. Configure every Release build setting currently containing `replace-before-release`, `replace-with`, or `dev.starter.app`. Backend endpoints must use HTTPS.
3. Create the matching app record in App Store Connect.
4. Verify every capability and identifier in Certificates, Identifiers & Profiles. Auth-enabled apps require Sign in with Apple.
5. Create an internal TestFlight group and add testers. Testers must accept their invitation before builds appear.
6. Add an active GitHub tag ruleset for `ios-beta-*` that restricts creation, updates, and deletions to release maintainers.

When Auth is installed, configure its Release endpoint. Keep `GOOGLE_AUTH_ENABLED = YES` and configure the three Google IDs, or set it to `NO` for an Apple-only app. Implement and test Sign in with Apple token revocation plus deletion of app-owned user data. Then add the user-defined Release build setting `AUTH_DELETION_LIFECYCLE_VERIFIED = YES`. The archive guard intentionally blocks Auth-enabled distribution until this app-specific lifecycle is acknowledged.

## Create the workflows

Open `apps/ios/Starter.xcodeproj` in Xcode and choose Product > Xcode Cloud > Create Workflow. Grant Xcode Cloud access to the repository when prompted.

Create `iOS Verify`:

- Start condition: changes to `main`
- Action: test `Starter` on one current iPhone simulator
- Distribution: none
- Auto-cancel superseded builds: enabled

Create `iOS Beta`:

- Start condition: Git tags beginning with `ios-beta-`
- Action: archive `Starter` for iOS using Release
- Deployment Preparation: TestFlight, internal testing only
- Post-action: distribute to the internal TestFlight group
- Auto-cancel superseded builds: disabled

The tag condition must be "begins with", not a tag literally named `ios-beta-*`.

## First release

1. Confirm GitHub CI and `iOS Verify` pass on `main`.
2. Review every privacy-purpose string required by the complete binary and its SDKs.
3. Push an annotated tag such as `ios-beta-20260715.1`.
4. Complete App Store Connect export compliance for the first accepted binary. If Apple determines a stable Info.plist value, record that answer in the project and revisit it when encryption use changes.
5. Confirm Xcode Cloud archives, processes, and assigns the build to the internal group automatically.
6. Install from TestFlight and verify authentication, backend connectivity, push notifications, and subscriptions on a physical device.

Repeat with `.2` rather than moving a failed or processed tag.

## Official references

- [Configure the first Xcode Cloud workflow](https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow)
- [Configure workflow actions](https://developer.apple.com/documentation/xcode/configuring-your-xcode-cloud-workflow-s-actions)
- [Write custom build scripts](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)
- [Add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers)
- [Export compliance overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)
