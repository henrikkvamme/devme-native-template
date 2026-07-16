import { createClient } from "@convex-dev/better-auth";
import { convex } from "@convex-dev/better-auth/plugins";
import type { GenericCtx } from "@convex-dev/better-auth/utils";
import { betterAuth, type BetterAuthOptions } from "better-auth/minimal";
import { bearer } from "better-auth/plugins";
import { importPKCS8, SignJWT } from "jose";

import { components } from "../_generated/api";
import type { DataModel } from "../_generated/dataModel";
import authConfig from "../auth.config";
import schema from "./schema";

const trimmedNonEmpty = (value: string | undefined): string | undefined => {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
};

const authBaseURL = () => {
  const fallback = trimmedNonEmpty(process.env.CONVEX_SITE_URL);
  if (!fallback) return undefined;

  const configuredHosts = (process.env.BETTER_AUTH_ALLOWED_HOSTS ?? "")
    .split(",")
    .map((host) => host.trim())
    .filter((host) => host.length > 0);
  return {
    allowedHosts: [...new Set([new URL(fallback).host, ...configuredHosts])],
    fallback,
    protocol: "auto" as const,
  };
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
  const teamId = trimmedNonEmpty(process.env.APPLE_TEAM_ID);
  const keyId = trimmedNonEmpty(process.env.APPLE_KEY_ID);
  const privateKey = trimmedNonEmpty(process.env.APPLE_PRIVATE_KEY);
  const appBundleIdentifier = trimmedNonEmpty(process.env.APPLE_APP_BUNDLE_IDENTIFIER);

  const values = { clientId, teamId, keyId, privateKey, appBundleIdentifier };
  const configured = Object.values(values).filter((value) => value !== undefined).length;
  if (configured === 0) return undefined;

  const missing = Object.entries(values)
    .filter(([, value]) => value === undefined)
    .map(([name]) => name);
  if (missing.length > 0) {
    throw new Error(`Apple auth configuration is incomplete: ${missing.join(", ")}`);
  }

  return async () => {
    const now = Math.floor(Date.now() / 1000);
    const signingKey = await importPKCS8(privateKey!, "ES256");
    const clientSecret = await new SignJWT({})
      .setProtectedHeader({ alg: "ES256", kid: keyId! })
      .setIssuer(teamId!)
      .setSubject(clientId!)
      .setAudience("https://appleid.apple.com")
      .setIssuedAt(now)
      .setExpirationTime(now + 180 * 24 * 60 * 60)
      .sign(signingKey);

    return {
      clientId: [...new Set([clientId!, appBundleIdentifier!])],
      clientSecret,
      appBundleIdentifier: appBundleIdentifier!,
    };
  };
};

export const authComponent = createClient<DataModel, typeof schema>(components.betterAuth, {
  local: { schema },
});

export const createAuthOptions = (ctx: GenericCtx<DataModel>) => {
  const google = googleProvider();
  const apple = appleProvider();
  return {
    appName: trimmedNonEmpty(process.env.AUTH_APP_NAME) ?? "Starter",
    baseURL: authBaseURL(),
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
    plugins: [bearer({ requireSignature: true }), convex({ authConfig, jwks: process.env.JWKS! })],
  } satisfies BetterAuthOptions;
};

// Better Auth CLI reads this export without invoking Convex runtime code.
export const options = createAuthOptions({} as GenericCtx<DataModel>);

export const createAuth = (ctx: GenericCtx<DataModel>) => betterAuth(createAuthOptions(ctx));
