# Devme Native Template

Native iOS and Android starter with a self-hosted Convex backend and Devme.

## Create

Install Devme:

```sh
curl -fsSL https://devme.sh/install | sh
```

```sh
devme create native my-app
cd my-app
```

Add optional capabilities when needed:

```sh
devme feature add auth
devme feature add billing-stripe-external
devme feature add release-ios
devme feature add release-android
```

External Stripe billing includes Auth. Use it only when the app and target stores permit external checkout. Feature changes install dependencies and reload services automatically.

## Run

```sh
devme
```

Rename the `Starter` targets and replace the `dev.starter.app` identifiers before shipping.

See [Auth and billing](docs/auth-and-billing.md) for provider setup.

## Ship

See [docs/ci-cd.md](docs/ci-cd.md) for CI, Xcode Cloud, TestFlight, and Google Play setup.
