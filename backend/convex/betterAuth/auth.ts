import { createClient } from "@convex-dev/better-auth";
import { convex } from "@convex-dev/better-auth/plugins";
import type { GenericCtx } from "@convex-dev/better-auth/utils";
import { stripe } from "@better-auth/stripe";
import { betterAuth, type BetterAuthOptions } from "better-auth/minimal";
import { bearer } from "better-auth/plugins";
import Stripe from "stripe";

import { components } from "../_generated/api";
import type { DataModel } from "../_generated/dataModel";
import authConfig from "../auth.config";
import schema from "./schema";

const trimmedNonEmpty = (value: string | undefined): string | undefined => {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
};

const googleProvider = () => {
  const clientIds = [
    trimmedNonEmpty(process.env.GOOGLE_WEB_CLIENT_ID),
    trimmedNonEmpty(process.env.GOOGLE_IOS_CLIENT_ID),
    trimmedNonEmpty(process.env.GOOGLE_ANDROID_CLIENT_ID),
  ].filter((value): value is string => value !== undefined);
  const clientSecret = trimmedNonEmpty(process.env.GOOGLE_CLIENT_SECRET);

  if (clientIds.length === 0 || !clientSecret) return undefined;
  return { clientId: clientIds, clientSecret };
};

const appleProvider = () => {
  const clientId = trimmedNonEmpty(process.env.APPLE_CLIENT_ID);
  const clientSecret = trimmedNonEmpty(process.env.APPLE_CLIENT_SECRET);
  const appBundleIdentifier = trimmedNonEmpty(process.env.APPLE_APP_BUNDLE_IDENTIFIER);

  if (!clientId || !clientSecret || !appBundleIdentifier) return undefined;
  return { clientId, clientSecret, appBundleIdentifier };
};

const stripeClient = new Stripe(
  trimmedNonEmpty(process.env.STRIPE_SECRET_KEY) ?? "sk_test_not_configured",
  {
    apiVersion: "2026-06-24.dahlia",
    httpClient: Stripe.createFetchHttpClient(),
  },
);

export const authComponent = createClient<DataModel, typeof schema>(components.betterAuth, {
  local: { schema },
});

export const createAuthOptions = (ctx: GenericCtx<DataModel>) => {
  const google = googleProvider();
  const apple = appleProvider();
  const stripePriceId = trimmedNonEmpty(process.env.STRIPE_PRICE_ID);

  return {
    appName: trimmedNonEmpty(process.env.AUTH_APP_NAME) ?? "Starter",
    baseURL: process.env.CONVEX_SITE_URL,
    secret: process.env.BETTER_AUTH_SECRET,
    database: authComponent.adapter(ctx),
    emailAndPassword: {
      enabled: process.env.AUTH_ENABLE_TEST_PASSWORD === "true",
    },
    socialProviders: {
      ...(google ? { google } : {}),
      ...(apple ? { apple } : {}),
    },
    trustedOrigins: ["https://appleid.apple.com"],
    plugins: [
      bearer({ requireSignature: true }),
      stripe({
        stripeClient,
        stripeWebhookSecret:
          trimmedNonEmpty(process.env.STRIPE_WEBHOOK_SECRET) ?? "whsec_not_configured",
        createCustomerOnSignUp: false,
        subscription: {
          enabled: true,
          plans: stripePriceId ? [{ name: "starter", priceId: stripePriceId }] : [],
        },
      }),
      convex({ authConfig, jwks: process.env.JWKS! }),
    ],
  } satisfies BetterAuthOptions;
};

// Better Auth CLI reads this export without invoking Convex runtime code.
export const options = createAuthOptions({} as GenericCtx<DataModel>);

export const createAuth = (ctx: GenericCtx<DataModel>) => betterAuth(createAuthOptions(ctx));
