# Google Play internal delivery

GitHub Actions builds a signed Android App Bundle from `android-beta-YYYYMMDD.N` tags and publishes it to Google Play's internal testing track.

## Play Console

1. Replace `dev.starter.app` with your package name.
2. Create the app in Play Console and enroll in Play App Signing.
3. Create the internal testing track, add a tester list, and save its opt-in link.
4. Build, sign, and upload the first app bundle manually in Play Console using the command below. The publishing API cannot bootstrap an unknown package.
5. Enable the Google Play Developer API in a Google Cloud project.
6. Create a dedicated service account, create and download one JSON key for it, invite the service account in Play Console, and grant only the app-level `Release apps to testing tracks` permission.
7. Add an active GitHub tag ruleset for `android-beta-*` that restricts creation, updates, and deletions to release maintainers.

## Upload key

Generate and back up a long-lived upload key. Do not commit it.

```sh
keytool -genkeypair -v -keystore upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Base64-encode the keystore and service-account JSON without line wrapping:

```sh
base64 < upload.jks | tr -d '\n'
base64 < google-play-service-account.json | tr -d '\n'
```

Build the initial signed bundle from a temporary shell, substituting production URLs and the values used when creating the upload key:

```sh
export ANDROID_UPLOAD_KEYSTORE_PATH="$PWD/upload.jks"
export ANDROID_UPLOAD_KEYSTORE_PASSWORD='replace-me'
export ANDROID_UPLOAD_KEY_ALIAS='upload'
export ANDROID_UPLOAD_KEY_PASSWORD='replace-me'
cd apps/android
./gradlew bundleRelease \
  -PreleaseConvexUrl=https://api.example.com
```

For an Auth-enabled app, the same preflight used by automation requires the public Google client ID, a public deletion page, and an explicit deletion-lifecycle verification:

```sh
export ANDROID_ACCOUNT_DELETION_URL=https://example.com/delete-account
export AUTH_DELETION_LIFECYCLE_VERIFIED=true
./gradlew bundleRelease \
  -PreleaseConvexUrl=https://api.example.com \
  -PreleaseAuthSiteUrl=https://auth.example.com \
  -PgoogleWebClientId=replace-with-google-web-client-id
```

Upload `app/build/outputs/bundle/release/app-release.aab` in Play Console, then clear the exported secrets from the shell.

## GitHub environment

Create the `google-play-internal` environment. Require a release-maintainer review and restrict deployment branches and tags to the protected `android-beta-*` tag pattern. This environment is the trust boundary for the signing and Play credentials.

Environment variables:

- `ANDROID_PACKAGE_NAME`
- `ANDROID_VERSION_NAME`, optional, defaults to `1.0`
- `ANDROID_CONVEX_URL`

When Auth is installed, also add:

- `ANDROID_AUTH_SITE_URL`
- `ANDROID_GOOGLE_WEB_CLIENT_ID`, the public Google web OAuth client ID
- `ANDROID_ACCOUNT_DELETION_URL`, the public HTTPS deletion page required by Google Play
- `AUTH_DELETION_LIFECYCLE_VERIFIED=true`, only after provider revocation and app-owned data cleanup are implemented and tested

Environment secrets:

- `ANDROID_UPLOAD_KEYSTORE_BASE64`
- `ANDROID_UPLOAD_KEYSTORE_PASSWORD`
- `ANDROID_UPLOAD_KEY_ALIAS`
- `ANDROID_UPLOAD_KEY_PASSWORD`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64`

The workflow fails before building when anything required is missing or when a release endpoint is not HTTPS.

## Publish

After GitHub CI passes on `main`, push an annotated tag such as `android-beta-20260715.1`. The date and sequence produce version code `2026071501`, below Google Play's `2100000000` limit. Use sequences 1 through 99 and never move or reuse a published tag.

The workflow preserves the signed AAB and mapping file for 30 days, then publishes the release to internal testing. Testers install through the Play opt-in link. The first test link can take several hours to become available.

## Official references

- [Prepare an app for release](https://developer.android.com/studio/publish/preparing)
- [Upload an app bundle](https://developer.android.com/studio/publish/upload-bundle)
- [Configure Google Play Developer API access](https://developers.google.com/android-publisher/getting_started)
- [Set up internal testing](https://support.google.com/googleplay/android-developer/answer/9845334)
- [Manage Play Console permissions](https://support.google.com/googleplay/android-developer/answer/9844686)
