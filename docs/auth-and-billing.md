# Auth and billing spike

This branch tests Better Auth and Stripe directly on self-hosted Convex. Hono is not required. It proves the backend session and JWT flow plus compile-time native transport bridges. It is not yet a finished auth UI or a live billing integration.

## Proven locally

```sh
devme run backend::auth-live-smoke --output toon
```

The check creates or restores a Better Auth bearer session, exchanges it for a Convex JWT, calls an authenticated Convex query, lists Stripe subscriptions, and verifies that an unsigned Stripe webhook is rejected.

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

The Swift and Kotlin `BetterAuthNativeClient` implementations contain this transport and implement the Convex auth-provider bridge. Platform-specific Apple and Google SDK adapters remain credential-dependent application code.

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

## Provisional starter decision

Keep the minimal default branch unauthenticated while this remains credential-unverified. If live Apple, Google, and Stripe tests pass, publish the completed integration as a separate auth-and-billing branch or template variant. The current evidence is enough to keep this complexity off the default branch, but not enough to choose or publish the final authenticated starter.
