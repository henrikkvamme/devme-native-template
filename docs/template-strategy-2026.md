# Template strategy for 2026

## Decision

Adopt a thin, verified native core plus versioned, opt-in feature modules. Trial the module installer against real downstream projects before making it the only distribution path. Keep a generated reference app with every supported module enabled and run its full iOS, Android, backend, and store-release checks in CI.

Do not use template branches or curated template commit history as the public feature-selection mechanism. Do not bundle generic Stripe subscriptions into the default native app. Auth should be an early opt-in module, while billing must be selected after the app's business model and store-policy path are known.

Confidence is high that Git history and template branches are the wrong mechanism, and medium that a module installer is the best long-term mechanism because add, update, and remove have not yet been exercised across several independently customized apps.

| Strategy                                                | Verdict                                                           | Decisive evidence                                                                                               | Main risk                                                                                                   |
| ------------------------------------------------------- | ----------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Auth and Stripe in the default branch                   | Hold - high confidence                                            | It makes account lifecycle, provider state, payment policy, and external resources mandatory for every app      | Agents can remove code but cannot safely reverse accounts, subscriptions, store records, or production data |
| Auth and payment as template branches                   | Hold - high confidence                                            | GitHub copies branches with unrelated histories that cannot be merged or used for pull requests                 | The advertised feature branch is not an installable feature                                                 |
| Auth and payment as carefully squashed template commits | Hold - high confidence                                            | A repository created from a GitHub template starts with one commit                                              | Downstream users never receive the curated commits to revert                                                |
| Versioned opt-in modules                                | Adopt as the target, Trial the implementation - medium confidence | It can encode source edits, account prerequisites, migrations, verification, and removal policy as one contract | Semantic updates and removal become a product that must be maintained and tested                            |
| Separate generated template variants                    | Trial as a transition - medium confidence                         | They give immediate working snapshots without depending on template history                                     | Independently maintained variants drift unless generated from one canonical composition                     |

## Why history is not the product interface

GitHub states that a repository created from a template starts with a single commit. Users can request all branches, but those branches have unrelated histories and cannot be merged or used for pull requests. A clean `auth` commit followed by a clean `payments` commit is useful maintainer history, but it gives template users no rollback surface. [GitHub template behavior](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template)

This means:

- Squashing before merge may improve this repository's maintainability.
- Rewriting shared `main` after merge does not improve the generated repository and disrupts existing clones.
- A feature installer may create one reviewed commit in the new app after installation. That commit is a useful local checkpoint, but it is not the authoritative uninstaller.
- Merging the current integrated branch to test it is reasonable while the template contract remains experimental. Preserve a core release tag first. Do not present the resulting full snapshot as universally production-ready.

The stronger current generator pattern is explicit composition. `create-t3-app` describes each stack piece as optional and generates the result for the selected needs rather than shipping an all-inclusive snapshot. Expo exposes a small template set, separate focused examples, and in 2026 generates agent instructions that point to documentation matching the selected SDK version. These are useful mechanisms, not popularity signals. [create-t3-app source](https://github.com/t3-oss/create-t3-app), [create-expo-app documentation](https://docs.expo.dev/more/create-expo/)

## Recommended product shape

### Default template

Keep the default branch small but complete:

- Native SwiftUI and Jetpack Compose applications.
- Self-hosted Convex connectivity and one reactive vertical slice.
- Shared wire contracts and generated client boundary where needed.
- Devme services, tasks, logs, device and simulator flows.
- Local and hosted verification for backend, iOS, and Android.
- Store delivery workflows that fail closed until real identifiers and credentials are configured.
- Lean `AGENTS.md` instructions with one canonical verification command, architecture seams, and links to current official docs. The open AGENTS.md project defines this file as a predictable repository-level instruction surface for coding agents. [AGENTS.md specification repository](https://github.com/agentsmd/agents.md)

The default should remain useful without an account. Apple's review guidelines say apps without significant account-based features should allow use without login. [Apple App Review Guidelines 5.1.1(v)](https://developer.apple.com/app-store/review/guidelines/)

### Feature modules

Use separate modules with explicit dependencies:

1. `auth-better-auth`
   - Better Auth on the Convex component.
   - Native Apple and Google provider adapters.
   - Secure session storage, authenticated Convex token exchange, profile UI, sign-out, and full account deletion.
   - Depends on finalized app identifiers and public backend origins.
2. `billing-store`
   - StoreKit and Google Play Billing for digital app features and subscriptions.
   - A shared backend entitlement interface, server notifications, restore, manage, and cancellation status.
   - Depends on auth or another explicit entitlement owner.
3. `billing-stripe`
   - Stripe for physical goods, physical services, consumption outside the app, or a specifically enrolled alternative-billing path.
   - Checkout, verified webhooks, customer portal, entitlement reconciliation, and deletion behavior.
   - Must require the adopter to declare the product category and target storefront policy path.

Do not combine auth and payment into one inseparable module. Billing may depend on identity, but identity does not depend on billing. Do not call a Stripe-enabled variant simply "full" or "SaaS" because that hides the store-policy decision.

### Generated variants

Until the module installer has proven safe updates and removal, publish at most:

- Core template.
- Authenticated template.
- A full reference app that is clearly non-generic and not itself the recommended starting point.

Generate each from the same canonical base and module recipes in CI. Never fix drift by manually cherry-picking between long-lived variant repositories.

## Failure-mode analysis

### Secrets and external account setup

Repository files can name required secrets, but cannot carry them. GitHub secrets are repository, organization, or environment state and must be explicitly exposed to a workflow. Deployment environments own approval rules, branch or tag restrictions, and environment secrets. Rulesets are repository or organization settings, although GitHub supports importing a ruleset JSON recipe. [GitHub secrets](https://docs.github.com/en/actions/concepts/security/secrets), [deployment environments](https://docs.github.com/en/actions/concepts/workflows-and-actions/deployment-environments), [ruleset import](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/managing-rulesets-for-a-repository)

Xcode Cloud is also account state. Apple requires the first workflow to be configured from Xcode, connected to the source provider, and associated with an App Store Connect product. Later workflows can be edited in Xcode or App Store Connect. Repository `ci_scripts` are portable and automatically discovered, but they do not recreate the workflow or its secrets. [Configuring the first Xcode Cloud workflow](https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow), [Xcode Cloud custom scripts](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)

Therefore every module needs a machine-readable preflight that reports:

- Missing account roles, agreements, identifiers, capabilities, OAuth clients, callback URLs, domains, products, prices, webhooks, environments, rulesets, and secrets.
- Which steps an agent can automate and which require a human authentication or legal boundary.
- Separate development and production readiness.
- No secret values in logs or the module lockfile.

### Native identity is not a text replacement

Apple requires a unique bundle identifier, developer team, provisioning, and the Sign in with Apple capability for native authentication. Supporting Apple authentication for a website or another platform also requires a Services ID and private key associated with a primary App ID. [Apple native Sign in setup](https://developer.apple.com/documentation/authenticationservices/implementing_user_authentication_with_sign_in_with_apple), [Apple web and other-platform setup](https://developer.apple.com/documentation/signinwithapple/configuring-your-environment-for-sign-in-with-apple)

Google's current Android path uses Credential Manager with a server client ID from Google Auth Platform, server-side token validation, optional nonce validation, and provider brand verification. [Android Sign in with Google](https://developer.android.com/identity/sign-in/credential-manager-siwg), [implementation guide](https://developer.android.com/identity/sign-in/credential-manager-siwg-implementation)

These values depend on the final app identity. Apple will not let an App Store Connect bundle ID change after a build is uploaded. Google Play says package names are unique and permanent. The setup flow must rename and verify the app before creating store and provider resources. [Apple app information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information), [Google Play app setup](https://support.google.com/googleplay/android-developer/answer/9859152)

### Auth includes deletion and data lifecycle

Better Auth's core and plugins own database schema. Its deletion endpoint is disabled by default and must be explicitly enabled and integrated. The Stripe plugin adds subscription tables, webhooks, management endpoints, and special handling for deleting users with active subscriptions. [Better Auth database](https://better-auth.com/docs/concepts/database), [Better Auth user deletion](https://better-auth.com/docs/concepts/users-accounts), [Better Auth Stripe plugin](https://better-auth.com/docs/plugins/stripe)

Once the app supports account creation, Apple requires users to initiate full deletion in the app and requires Sign in with Apple token revocation. Google Play requires both an in-app deletion path and an external web deletion resource. [Apple account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app), [Google Play account deletion](https://support.google.com/googleplay/android-developer/answer/13327111)

The auth module is not releasable until both platforms prove:

- Apple and Google sign-in on physical devices.
- Session refresh and authenticated Convex access.
- Account linking and collision behavior.
- Sign-out and secure local credential removal.
- Account deletion, provider token revocation, application-data deletion, and billing interaction.
- App review and Play Data safety documentation paths.

### Schema and production data do not follow Git

Convex components encapsulate functions, schemas, and persistent tables behind explicit APIs. This is a strong module boundary, but removing component code does not answer whether user and subscription data should be retained, migrated, or deleted. Convex enforces that deployed schemas match existing data, and recommends staged, forward migrations. Its backups contain table documents and files but exclude code, environment variables, and scheduled functions. [Convex components](https://docs.convex.dev/components/understanding), [safe production schema changes](https://docs.convex.dev/production/overview), [backup and restore](https://docs.convex.dev/database/backup-restore)

An auth or billing removal must therefore be a forward operation:

1. Stop new creation and expose a maintenance state.
2. Export or back up data.
3. Drain sessions, webhooks, and scheduled work.
4. Migrate or deliberately retain application references.
5. Remove routes, UI, provider credentials, and capabilities.
6. Delete data only behind a separate explicit purge confirmation.

`git revert` covers source only. It cannot be called an end-to-end rollback.

### Stripe is not the generic native billing default

Apple requires In-App Purchase when payment unlocks digital features or content, while physical goods and services must use other methods. Google Play likewise requires Play Billing for digital features unless a current regional program or exception applies. Google is changing billing programs and fees during 2026, so this decision must be rechecked for the app's launch regions. [Apple App Review Guidelines 3.1](https://developer.apple.com/app-store/review/guidelines/), [Google Play Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738), [Google Play 2026 billing changes](https://support.google.com/googleplay/android-developer/answer/16954621)

Stripe subscription state is asynchronous. Stripe instructs integrations to verify and process lifecycle webhooks, and its customer portal manages payment methods, invoices, plan changes, and cancellations. Removing checkout code while leaving subscriptions or webhooks active can grant stale entitlements or continue billing without an in-app management path. [Stripe subscription webhooks](https://docs.stripe.com/billing/subscriptions/webhooks), [Stripe customer portal](https://docs.stripe.com/customer-management)

This is the strongest reason not to ship payments enabled in the generic default.

## Agent-first module contract

Each module should have a tracked manifest containing:

- Module version and source recipe commit SHA.
- Dependencies and conflicts.
- Stable integration seams and files or generated regions it owns.
- Required app identifiers, capabilities, provider resources, secrets, account roles, and policies.
- Non-secret external resource identifiers created during setup.
- Schema and data migrations already applied.
- Verification commands and expected machine-readable results.
- Disable, preserve-data removal, and destructive purge procedures.

The UX should support:

```text
devme starter status
devme starter plan add auth-better-auth
devme starter add auth-better-auth --providers apple,google
devme starter plan add billing-stripe
devme starter update
devme starter plan remove auth-better-auth
devme starter remove auth-better-auth --preserve-data
```

Requirements:

- `plan` is read-only and reports source, schema, provider, and account changes.
- `add` is idempotent and fails closed on partial configuration.
- `update` understands the installed module version and emits a reviewable change.
- `remove` defaults to disabling and preserving external state.
- Purge is separate, explicit, and unavailable while active subscriptions or unmigrated accounts exist.
- Successful add or remove creates one downstream commit after all verification passes.
- Every command has structured output suitable for an agent and concise remediation links to current official documentation.

Prefer narrow owned seams over patching arbitrary Swift, Kotlin, and TypeScript files. Examples include one backend component registry, one authentication provider interface, one entitlement interface, one settings-section registry, and generated capability or build configuration. If a module routinely conflicts with application code, deepen the seam rather than adding more patch heuristics.

## Validation before publishing the installer

Run the following trial on at least three independently customized apps:

1. Create from the core template and rename all identities.
2. Add auth, configure real Apple and Google sandbox credentials, and pass physical-device E2E tests.
3. Update the auth module across one breaking Better Auth or Convex component release.
4. Add the appropriate billing module and prove purchase, renewal, cancellation, restore, webhook replay, and entitlement convergence.
5. Remove billing with preserved data.
6. Remove auth after migrating or deleting accounts.
7. Repeat after unrelated changes to settings UI, backend schema, and CI.

Acceptance requires deterministic plans, no lost user data, no duplicated subscriptions, no orphaned secrets or provider callbacks, no manual source conflict resolution on the declared seams, and green `devme run verify`. Until this passes, keep generated variants available as the safe fallback.

## Reversal conditions and review date

Reverse from modules to generated variants if representative downstream trials cannot add, update, and remove features without manual conflict resolution or unclear data ownership. Bundle auth in the default only if the supported product category is narrowed so every generated app demonstrably requires identity and the complete deletion lifecycle remains verified. Bundle Stripe only if the template is narrowed to a policy-compatible commerce category and launch-region requirements are encoded and tested.

Reconsider the history conclusion only if GitHub changes template generation to preserve useful commit ancestry or an upstream relationship. Recheck payment policy before every store launch and by January 2027. Recheck the module boundary after any major Convex, Better Auth, Xcode, Android identity, StoreKit, Play Billing, or Stripe integration change.
