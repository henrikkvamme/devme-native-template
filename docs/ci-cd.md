# CI and delivery

The starter uses one portable CI workflow and separate store-owned delivery lanes.

| Trigger                             | System         | Result                                                         |
| ----------------------------------- | -------------- | -------------------------------------------------------------- |
| Pull request, `main`, or manual run | GitHub Actions | Devme core checks, iOS unit tests, Android unit tests and lint |
| `ios-beta-YYYYMMDD.N`               | Xcode Cloud    | Signed archive distributed to internal TestFlight testers      |
| `android-beta-YYYYMMDD.N`           | GitHub Actions | Signed app bundle distributed to Google Play internal testers  |

Set up [Xcode Cloud](ios-xcode-cloud.md) and [Google Play](android-google-play.md) after renaming the app and replacing every `dev.starter.app` identifier.

Before creating release tags, add an active GitHub tag ruleset matching `ios-beta-*` and `android-beta-*` that restricts creation, updates, and deletions to release maintainers. The Android release environment must require a reviewer and allow only the protected beta tags. Repository templates do not copy rulesets, environments, variables, secrets, App Store Connect products, or Xcode Cloud workflows.

Never move or reuse a published release tag. Fix the commit and increment `N`, from 1 through 99 for that date.
