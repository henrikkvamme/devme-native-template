# Native authentication

The `auth` feature adds Better Auth on Convex, native Sign in with Apple on iOS, Google Sign-In on iOS, and Android Credential Manager Google sign-in. Session tokens are stored in Keychain or Android Keystore. Both apps include sign-out and permanent account deletion.

## Configure

1. Choose final iOS and Android identifiers.
2. Run `devme`. Its required Apple and Google environment setup writes provider values to the ignored `.env.auth.local` file. The committed `.env.auth.example` remains a reference.
3. Configure the provider credentials you need in that setup.
4. Apply and validate them:

```sh
devme run backend::auth-configure --output toon
devme run backend::auth-doctor --output toon
devme run backend::auth-live-smoke --output toon
```

For Android, pass the Google web client ID when building:

```sh
cd apps/android
./gradlew assembleDebug -PgoogleWebClientId="$GOOGLE_WEB_CLIENT_ID"
```

Apple sign-in on Android is a browser OAuth flow, not an Android native identity API. Add it only after choosing the final redirect domain and application link. The included Android native flow intentionally uses Credential Manager for Google.

## Release checks

- Use production HTTPS Convex sync and HTTP-action URLs.
- Verify sign-in, session restoration, authenticated Convex access, sign-out, and account deletion on physical devices.
- Account deletion reauthenticates before calling Better Auth, satisfying its fresh-session requirement. Before release, add Sign in with Apple token revocation and cleanup for any user-owned domain data. Google Play also requires a public web deletion path.
- Re-read provider and store requirements before each release.

## Official documentation

- [Better Auth user deletion](https://better-auth.com/docs/concepts/users-accounts)
- [Convex Better Auth component](https://labs.convex.dev/better-auth)
- [Sign in with Apple](https://developer.apple.com/documentation/authenticationservices/implementing-user-authentication-with-sign-in-with-apple)
- [Configure Sign in with Apple](https://developer.apple.com/documentation/signinwithapple/configuring-your-environment-for-sign-in-with-apple)
- [Create a Sign in with Apple private key](https://developer.apple.com/help/account/capabilities/create-a-sign-in-with-apple-private-key/)
- [Google Sign-In for iOS](https://developers.google.com/identity/sign-in/ios/start-integrating)
- [Credential Manager Sign in with Google](https://developer.android.com/identity/sign-in/credential-manager-siwg)
- [Apple account deletion requirement](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [Google Play account deletion requirement](https://support.google.com/googleplay/android-developer/answer/13327111)
