import { ConvexHttpClient } from "convex/browser";

import { api } from "../convex/_generated/api";

const convexURL = process.env.CONVEX_URL;
const authSiteURL = process.env.AUTH_SITE_URL;

if (!convexURL || !authSiteURL) {
  throw new Error("CONVEX_URL and AUTH_SITE_URL are required");
}

const expectStatus = async (response: Response, expected: number) => {
  if (response.status !== expected) {
    throw new Error(`${response.url} returned ${response.status}: ${await response.text()}`);
  }
};

const credentials = {
  email: "devme-auth-smoke@example.test",
  password: "Local-only-auth-smoke-2026!",
};

let sessionResponse = await fetch(`${authSiteURL}/api/auth/sign-up/email`, {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ ...credentials, name: "Devme Auth Smoke" }),
});

if (!sessionResponse.ok) {
  sessionResponse = await fetch(`${authSiteURL}/api/auth/sign-in/email`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(credentials),
  });
}

await expectStatus(sessionResponse, 200);
const bearerToken = sessionResponse.headers.get("set-auth-token");
if (!bearerToken) throw new Error("Better Auth did not return a bearer token");

const tokenResponse = await fetch(`${authSiteURL}/api/auth/convex/token`, {
  headers: { authorization: `Bearer ${bearerToken}` },
});
await expectStatus(tokenResponse, 200);
const tokenBody = (await tokenResponse.json()) as { token?: unknown };
if (typeof tokenBody.token !== "string") {
  throw new Error("Better Auth did not return a Convex JWT");
}

const convex = new ConvexHttpClient(convexURL);
convex.setAuth(tokenBody.token);
const profileImage = "https://example.com/devme-auth-smoke-profile.png";
const updateUserResponse = await fetch(`${authSiteURL}/api/auth/update-user`, {
  method: "POST",
  headers: {
    authorization: `Bearer ${bearerToken}`,
    "content-type": "application/json",
  },
  body: JSON.stringify({ image: profileImage }),
});
await expectStatus(updateUserResponse, 200);

const currentSessionResponse = await fetch(`${authSiteURL}/api/auth/get-session`, {
  headers: { authorization: `Bearer ${bearerToken}` },
});
await expectStatus(currentSessionResponse, 200);
const currentSession = (await currentSessionResponse.json()) as {
  user?: { email?: string; image?: string | null };
};
if (
  currentSession.user?.email !== credentials.email ||
  currentSession.user.image !== profileImage
) {
  throw new Error("Better Auth did not persist the authenticated profile image");
}

const viewer = await convex.query(api.auth.current, {});
if (viewer?.email !== credentials.email || viewer.image !== profileImage) {
  throw new Error("Convex did not resolve the authenticated Better Auth profile");
}

console.log(
  JSON.stringify({
    auth: "passed",
    convexIdentity: "passed",
    profileImage: "passed",
  }),
);
