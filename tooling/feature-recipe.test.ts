import { readFileSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

const root = join(import.meta.dirname, "..");
const read = (path: string) => readFileSync(join(root, path), "utf8");

describe("native feature recipe", () => {
  it("keeps auth independent from Stripe", () => {
    expect(read("features/auth/backend/package.json")).not.toContain("@better-auth/stripe");
    expect(read("features/auth/backend/convex/betterAuth/auth.ts")).not.toContain(
      "@better-auth/stripe",
    );
    expect(read("features/auth/backend/devme.toml")).not.toContain("stripe-webhooks");
    expect(read("features/auth/apps/ios/Starter/Info.plist")).not.toContain("billing");
  });

  it("declares Stripe as an auth-dependent, reversible feature", () => {
    const manifest = read("devme-template.toml");
    expect(manifest).toContain("[features.auth]");
    expect(manifest).toContain("[features.stripe]");
    expect(manifest).toContain('dependencies = ["auth"]');
    expect(manifest.match(/remove_external_steps/g)).toHaveLength(2);
    expect(read("features/stripe/backend/package.json")).toContain("@better-auth/stripe");
    expect(read("features/stripe/tooling/stripe-webhooks.sh")).toContain("stripe listen");
  });
});
