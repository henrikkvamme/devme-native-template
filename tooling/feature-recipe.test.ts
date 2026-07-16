import { readFileSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

const root = join(import.meta.dirname, "..");
const read = (path: string) => readFileSync(join(root, path), "utf8");

describe("native feature recipe", () => {
  it("keeps auth independent from Stripe", () => {
    expect(read("features/auth/backend/package.json")).not.toContain("@better-auth/stripe");
    expect(read("features/auth/backend/package.json")).not.toContain("@better-auth/cli");
    expect(read("features/auth/backend/package.json")).toContain('"auth": "1.6.23"');
    expect(read("features/auth/backend/convex/betterAuth/auth.ts")).not.toContain(
      "@better-auth/stripe",
    );
    expect(read("features/auth/backend/devme.toml")).not.toContain("stripe-webhooks");
    expect(read("features/auth/contracts/function-spec.json")).not.toContain(
      "subscriptionForDiagnostics",
    );
    expect(read("features/auth/apps/ios/Starter/Info.plist")).not.toContain("billing");
    expect(read("features/auth/apps/android/app/build.gradle.kts")).toContain(
      "ANDROID_UPLOAD_KEYSTORE",
    );
    expect(read("features/auth/infrastructure/convex/compose.yaml")).toContain(
      'restart: "on-failure:5"',
    );
    expect(read("features/auth/.github/workflows/ci.yml")).toContain(
      "b14b342915841bdb4ebdc380ea81d715b630f107",
    );
  });

  it("declares external Stripe billing as an auth-dependent, reversible feature", () => {
    const manifest = read("devme-template.toml");
    expect(manifest).toContain("[features.auth]");
    expect(manifest).toContain("[features.billing-stripe-external]");
    expect(manifest).toContain('dependencies = ["auth"]');
    expect(manifest.match(/remove_external_steps/g)).toHaveLength(4);
    expect(read("features/billing-stripe-external/backend/package.json")).toContain(
      "@better-auth/stripe",
    );
    expect(read("features/billing-stripe-external/backend/package.json")).toContain(
      '"auth": "1.6.23"',
    );
    expect(read("features/billing-stripe-external/backend/convex/betterAuth/auth.ts")).toContain(
      "ACTIVE_SUBSCRIPTION",
    );
    expect(
      read(
        "features/billing-stripe-external/apps/ios/Starter/Backend/BetterAuthNativeClient.swift",
      ),
    ).toContain("subscription/billing-portal");
    expect(
      read(
        "features/billing-stripe-external/apps/android/app/src/main/java/dev/starter/app/BetterAuthNativeClient.kt",
      ),
    ).toContain("subscription/billing-portal");
    expect(
      read(
        "features/billing-stripe-external/apps/android/app/src/main/java/dev/starter/app/MainActivity.kt",
      ),
    ).toContain("Manage subscription");
    expect(read("features/billing-stripe-external/tooling/stripe-webhooks.sh")).toContain(
      "stripe listen",
    );
    expect(read("features/billing-stripe-external/tooling/stripe-webhooks.sh")).toContain(
      "starter-$workspace_key-$slot-backend-1",
    );
    expect(read("features/billing-stripe-external/contracts/function-spec.json")).toContain(
      "subscriptionForDiagnostics",
    );
  });

  it("keeps release delivery optional and platform-specific", () => {
    const manifest = read("devme-template.toml");
    expect(manifest).toContain("[features.release-ios]");
    expect(manifest).toContain("[features.release-android]");
    expect(read("features/release-ios/docs/ios-xcode-cloud.md")).toContain("Xcode Cloud");
    expect(read("features/release-ios/apps/ios/ci_scripts/ci_pre_xcodebuild.sh")).toContain(
      'if [ -f "$project_dir/Starter/Backend/BetterAuthNativeClient.swift" ]',
    );
    expect(read("features/release-android/.github/workflows/android-internal.yml")).toContain(
      "workflow_dispatch",
    );
    expect(read("features/release-android/.github/workflows/android-internal.yml")).toContain(
      "ANDROID_GOOGLE_WEB_CLIENT_ID",
    );
    expect(read("tooling/android-release-preflight.sh")).toContain("RELEASE_APPLICATION_ID");
  });

  it("reauthenticates deletion and exposes app-specific release gates", () => {
    expect(read("features/auth/backend/convex/betterAuth/auth.ts")).toContain(
      "deleteUser: { enabled: true }",
    );
    expect(read("features/auth/apps/ios/Starter/Features/Settings/SettingsView.swift")).toContain(
      "Verify your identity",
    );
    expect(read("features/auth/apps/ios/Starter/Features/Settings/SettingsView.swift")).toContain(
      "freshViewer.subject == originalViewer.subject",
    );
    expect(read("features/auth/apps/android/app/build.gradle.kts")).toContain(
      "androidx.credentials:credentials",
    );
    expect(
      read(
        "features/auth/apps/android/app/src/main/java/dev/starter/app/BetterAuthNativeClient.kt",
      ),
    ).toContain("GetSignInWithGoogleOption");
    expect(
      read(
        "features/auth/apps/android/app/src/main/java/dev/starter/app/BetterAuthNativeClient.kt",
      ),
    ).toContain("freshSession");
    expect(
      read(
        "features/auth/apps/android/app/src/main/java/dev/starter/app/AuthenticationController.kt",
      ),
    ).toContain("freshSession.subject != expectedSubject");
    expect(read("features/auth/docs/auth.md")).toContain("token revocation");
    expect(
      read("features/auth/apps/android/app/src/main/java/dev/starter/app/MainActivity.kt"),
    ).not.toContain('PlaceholderScreen("Settings"');
  });
});
