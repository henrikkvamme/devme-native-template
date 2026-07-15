import { parse } from "dotenv";
import { describe, expect, it } from "vitest";

import {
  externalConfigurationReady,
  groupReadiness,
  iosXCConfig,
  prepareConfiguration,
  serializeConfiguration,
} from "../../tooling/auth-config";

describe("auth configuration", () => {
  it("prepares a complete Apple configuration without exposing the key path", async () => {
    const configuration = await prepareConfiguration(
      [
        "APPLE_CLIENT_ID=com.acme.service",
        "APPLE_TEAM_ID=TEAM123",
        "APPLE_KEY_ID=KEY123",
        "APPLE_PRIVATE_KEY_FILE=/keys/AuthKey.p8",
        "APPLE_APP_BUNDLE_IDENTIFIER=com.acme.app",
      ].join("\n"),
      "/workspace",
      async (path) => {
        expect(path).toBe("/keys/AuthKey.p8");
        return "-----BEGIN PRIVATE KEY-----\nsecret\n-----END PRIVATE KEY-----";
      },
    );

    expect(configuration.APPLE_PRIVATE_KEY_FILE).toBeUndefined();
    expect(configuration.APPLE_PRIVATE_KEY).toContain("BEGIN PRIVATE KEY");
    expect(groupReadiness(configuration).find(({ name }) => name === "apple")?.status).toBe(
      "ready",
    );
  });

  it("rejects partial provider groups before mutating Convex", async () => {
    await expect(
      prepareConfiguration("GOOGLE_IOS_CLIENT_ID=ios.apps.googleusercontent.com", "/workspace"),
    ).rejects.toThrow("google is missing");
  });

  it("generates local iOS build settings from Google OAuth clients", () => {
    expect(
      iosXCConfig({
        GOOGLE_WEB_CLIENT_ID: "123-web.apps.googleusercontent.com",
        GOOGLE_IOS_CLIENT_ID: "123-ios.apps.googleusercontent.com",
      }),
    ).toBe(
      [
        "GOOGLE_IOS_CLIENT_ID = 123-ios.apps.googleusercontent.com",
        "GOOGLE_SERVER_CLIENT_ID = 123-web.apps.googleusercontent.com",
        "GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.123-ios",
        "",
      ].join("\n"),
    );
  });

  it("accepts a complete Stripe group without requiring unrelated providers", async () => {
    const configuration = await prepareConfiguration(
      ["STRIPE_SECRET_KEY=sk_test_realistic", "STRIPE_PRICE_ID=price_realistic"].join("\n"),
      "/workspace",
    );

    expect(groupReadiness(configuration).find(({ name }) => name === "stripe")?.status).toBe(
      "ready",
    );
    expect(externalConfigurationReady(groupReadiness(configuration))).toBe(true);
    expect(configuration.APPLE_PRIVATE_KEY).toBeUndefined();
  });

  it("rejects unknown variables and placeholder values", async () => {
    await expect(
      prepareConfiguration(
        [
          "STRIPE_SECRET_KEY=sk_test_realistic",
          "STRIPE_WEBHOOK_SECRET=whsec_realistic",
          "STRIPE_PRICE_ID=price_realistic",
          "STRIPE_SECRT_KEY=typo",
        ].join("\n"),
        "/workspace",
      ),
    ).rejects.toThrow("Unknown auth configuration");

    await expect(
      prepareConfiguration(
        [
          "STRIPE_SECRET_KEY=replace_me",
          "STRIPE_WEBHOOK_SECRET=whsec_realistic",
          "STRIPE_PRICE_ID=price_realistic",
        ].join("\n"),
        "/workspace",
      ),
    ).rejects.toThrow("placeholder value");
  });

  it("round trips multiline secrets through dotenv", () => {
    const serialized = serializeConfiguration({
      APPLE_PRIVATE_KEY: "first\nsecond",
      AUTH_APP_NAME: "Starter",
    });
    expect(parse(serialized)).toEqual({
      APPLE_PRIVATE_KEY: "first\nsecond",
      AUTH_APP_NAME: "Starter",
    });
  });

  it("reports all external groups without exposing their values", () => {
    expect(groupReadiness({})).toEqual([
      {
        name: "google",
        status: "missing",
        missing: ["GOOGLE_WEB_CLIENT_ID", "GOOGLE_IOS_CLIENT_ID", "GOOGLE_CLIENT_SECRET"],
      },
      {
        name: "apple",
        status: "missing",
        missing: [
          "APPLE_CLIENT_ID",
          "APPLE_TEAM_ID",
          "APPLE_KEY_ID",
          "APPLE_PRIVATE_KEY_FILE",
          "APPLE_APP_BUNDLE_IDENTIFIER",
        ],
      },
      {
        name: "stripe",
        status: "missing",
        missing: ["STRIPE_SECRET_KEY", "STRIPE_PRICE_ID"],
      },
    ]);
  });
});
