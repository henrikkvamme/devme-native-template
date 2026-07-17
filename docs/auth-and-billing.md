# Auth and Stripe

Auth uses Better Auth directly on self-hosted Convex. Stripe extends Auth with subscriptions, checkout, webhook synchronization, and customer management. Hono is not required.

## Add

```sh
devme feature add auth
devme feature add billing-stripe-external
```

External Stripe billing installs Auth automatically. Use it only for an app, store, and region where external checkout is permitted. Devme installs changed dependencies and reloads the service graph in the same command.

Run `devme` and complete its environment setup for the providers you need. Devme writes the ignored `.env.auth.local` file. Then apply it:

```sh
devme run backend::auth-configure --output toon
```

## Verify

```sh
devme run backend::auth-live-smoke --output toon
```

The smoke check creates a Better Auth session, exchanges it for a Convex JWT, calls an authenticated Convex query, reads subscriptions, and rejects an unsigned Stripe webhook.

App launch tasks also start `backend::stripe-webhooks`. It uses the configured Stripe sandbox key, injects the matching Stripe CLI signing secret into local Convex, and forwards checkout and subscription lifecycle events. No separate `stripe listen` command is required.

After a sandbox checkout, agents can verify that Stripe and Better Auth agree:

```sh
devme run backend::billing-doctor --output toon
```

## Native flow

1. The Apple or Google native SDK returns an ID token.
2. The app posts it to `/api/auth/sign-in/social` on the Convex HTTP-action URL.
3. Better Auth returns `set-auth-token`. Store this long-lived session token in Keychain or Android Keystore storage.
4. The app sends that bearer token to `/api/auth/convex/token` when the Convex client needs a short-lived JWT.
5. `ConvexClientWithAuth` uses the JWT for authenticated queries and refreshes it through the same endpoint.

The iOS feature includes native Apple and Google sign-in, Keychain session storage, profile presentation, authenticated pings, subscription state, checkout, customer-portal management, sign-out, and account deletion. Android includes Credential Manager Google sign-in, Android Keystore session storage, authenticated pings, subscription state, checkout, customer-portal management, sign-out, and account deletion. Apple sign-in on Android remains an app-specific browser OAuth flow.

Convex sync and HTTP actions use different URLs. Local slot 0 uses `http://127.0.0.1:3210` for sync and `http://127.0.0.1:3211` for auth. The physical-device Devme helper exposes both through private Tailscale HTTPS endpoints.

## Production configuration

Set these on the Convex deployment:

- `BETTER_AUTH_SECRET`
- `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID`, `GOOGLE_ANDROID_CLIENT_ID`, and `GOOGLE_CLIENT_SECRET`
- `APPLE_CLIENT_ID`, `APPLE_CLIENT_SECRET`, and `APPLE_APP_BUNDLE_IDENTIFIER`
- `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, and `STRIPE_PRICE_ID`
- `JWKS`, generated after the first deployment

Configure the production Stripe webhook as `/api/auth/stripe/webhook` and subscribe to `checkout.session.completed` plus the created, updated, and deleted customer subscription events. Use the endpoint signing secret as `STRIPE_WEBHOOK_SECRET`. The local Devme listener is only for sandbox development. Production Convex origins must use the real public sync and HTTP-action domains.

## Confect constraint

Confect owns the Convex functions directory and deletes handwritten Better Auth modules. `tooling/backend-codegen.sh` therefore applies a reviewed auth overlay after Confect code generation, regenerates the Better Auth schema, and formats the result. This seam is deterministic, but it is the main added complexity of keeping Confect with Better Auth.

Deletion reauthenticates the user so Better Auth receives a fresh session. It is blocked while Stripe still reports a live subscription, and the customer portal remains available for cancellation. This starter has no user-owned domain tables. Before release, extend the deletion callbacks to remove any app-owned user data and revoke Sign in with Apple tokens. Google Play also requires a public web deletion path. Removing source does not revoke provider credentials, delete accounts, cancel subscriptions, or remove Stripe webhooks. Complete the external cleanup steps reported by Devme.
