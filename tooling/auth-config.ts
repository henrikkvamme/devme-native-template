#!/usr/bin/env bun

import { homedir } from "node:os";
import { isAbsolute, resolve } from "node:path";

import { parse } from "dotenv";

const officialDocs = {
  convexBetterAuth: "https://labs.convex.dev/better-auth",
  betterAuthGoogle: "https://better-auth.com/docs/authentication/google",
  betterAuthApple: "https://better-auth.com/docs/authentication/apple",
  betterAuthStripe: "https://better-auth.com/docs/plugins/stripe",
} as const;

const groups = {
  google: {
    accepted: [
      "GOOGLE_WEB_CLIENT_ID",
      "GOOGLE_IOS_CLIENT_ID",
      "GOOGLE_ANDROID_CLIENT_ID",
      "GOOGLE_CLIENT_SECRET",
    ],
    required: ["GOOGLE_IOS_CLIENT_ID", "GOOGLE_ANDROID_CLIENT_ID", "GOOGLE_CLIENT_SECRET"],
  },
  apple: {
    accepted: [
      "APPLE_CLIENT_ID",
      "APPLE_TEAM_ID",
      "APPLE_KEY_ID",
      "APPLE_PRIVATE_KEY_FILE",
      "APPLE_PRIVATE_KEY",
      "APPLE_APP_BUNDLE_IDENTIFIER",
    ],
    required: [
      "APPLE_CLIENT_ID",
      "APPLE_TEAM_ID",
      "APPLE_KEY_ID",
      "APPLE_PRIVATE_KEY_FILE",
      "APPLE_APP_BUNDLE_IDENTIFIER",
    ],
  },
  stripe: {
    accepted: ["STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET", "STRIPE_PRICE_ID"],
    required: ["STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET", "STRIPE_PRICE_ID"],
  },
} as const;

type GroupName = keyof typeof groups;
type Configuration = Record<string, string>;
type GroupReadiness = {
  name: GroupName;
  status: "ready" | "missing" | "partial";
  missing: string[];
};

const allowedKeys = new Set([
  "AUTH_APP_NAME",
  ...Object.values(groups).flatMap(({ accepted }) =>
    accepted.filter((key) => key !== "APPLE_PRIVATE_KEY"),
  ),
]);

const valueIsSet = (value: string | undefined) => value !== undefined && value.trim().length !== 0;

const expandHome = (path: string) =>
  path === "~" || path.startsWith("~/") ? path.replace(/^~/, homedir()) : path;

const placeholderValue = (value: string) =>
  /(^|[._/-])(replace|example|your)([._/-]|$)|<[^>]+>|\.invalid$/i.test(value);

export const groupReadiness = (configuration: Configuration): GroupReadiness[] =>
  Object.entries(groups).map(([name, group]) => {
    const present = group.accepted.filter((key) => valueIsSet(configuration[key]));
    const missing = group.required.filter((key) => {
      if (key === "APPLE_PRIVATE_KEY_FILE") {
        return (
          !valueIsSet(configuration.APPLE_PRIVATE_KEY_FILE) &&
          !valueIsSet(configuration.APPLE_PRIVATE_KEY)
        );
      }
      return !valueIsSet(configuration[key]);
    });
    return {
      name: name as GroupName,
      status: present.length === 0 ? "missing" : missing.length === 0 ? "ready" : "partial",
      missing,
    };
  });

export const externalConfigurationReady = (readiness: GroupReadiness[]) =>
  readiness.some(({ status }) => status === "ready") &&
  readiness.every(({ status }) => status !== "partial");

export const prepareConfiguration = async (
  contents: string,
  cwd: string,
  readTextFile: (path: string) => Promise<string> = async (path) => Bun.file(path).text(),
): Promise<Configuration> => {
  const parsed = parse(contents);
  const unknown = Object.keys(parsed).filter((key) => !allowedKeys.has(key));
  if (unknown.length > 0) {
    throw new Error(`Unknown auth configuration: ${unknown.join(", ")}`);
  }

  const configuration: Configuration = {};
  for (const [key, value] of Object.entries(parsed)) {
    const trimmed = value?.trim();
    if (trimmed) configuration[key] = trimmed;
  }
  const readiness = groupReadiness(configuration);
  const partial = readiness.filter(({ status }) => status === "partial");
  if (partial.length > 0) {
    throw new Error(
      partial.map(({ name, missing }) => `${name} is missing ${missing.join(", ")}`).join("; "),
    );
  }
  if (!readiness.some(({ status }) => status === "ready")) {
    throw new Error("Configure at least one complete provider group");
  }

  for (const [key, value] of Object.entries(configuration)) {
    if (key !== "APPLE_PRIVATE_KEY_FILE" && placeholderValue(value)) {
      throw new Error(`${key} still contains a placeholder value`);
    }
  }

  if (valueIsSet(configuration.APPLE_PRIVATE_KEY_FILE)) {
    const configuredPath = expandHome(configuration.APPLE_PRIVATE_KEY_FILE!);
    const privateKeyPath = isAbsolute(configuredPath)
      ? configuredPath
      : resolve(cwd, configuredPath);
    let privateKey: string;
    try {
      privateKey = (await readTextFile(privateKeyPath)).trim();
    } catch {
      throw new Error(`APPLE_PRIVATE_KEY_FILE is not readable: ${privateKeyPath}`);
    }
    if (
      !privateKey.startsWith("-----BEGIN PRIVATE KEY-----") ||
      !privateKey.endsWith("-----END PRIVATE KEY-----")
    ) {
      throw new Error("APPLE_PRIVATE_KEY_FILE must contain an Apple PKCS#8 .p8 private key");
    }
    delete configuration.APPLE_PRIVATE_KEY_FILE;
    configuration.APPLE_PRIVATE_KEY = privateKey;
  }

  return configuration;
};

export const serializeConfiguration = (configuration: Configuration) =>
  Object.entries(configuration)
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, value]) => `${key}=${JSON.stringify(value)}`)
    .join("\n") + "\n";

const toonString = (value: string) => JSON.stringify(value);

const printUsageError = (message: string) => {
  console.log(`error: ${toonString(message)}`);
  console.log(
    'help[1]: "Run `devme tasks show backend::auth-doctor --output toon` to inspect the supported workflow."',
  );
};

const parseFlag = (arguments_: string[], name: string) => {
  const index = arguments_.indexOf(name);
  if (index === -1) return undefined;
  const value = arguments_[index + 1];
  if (!value || value.startsWith("--")) throw new Error(`${name} requires a value`);
  arguments_.splice(index, 2);
  return value;
};

const printHelp = () => {
  console.log("bin: tooling/auth-config.ts");
  console.log('description: "Validate and inspect native auth and billing configuration"');
  console.log("commands[3]{name,flags}:");
  console.log('  prepare,"--input <path> --output <path>"');
  console.log('  applied,"--input <path>"');
  console.log('  doctor,"--strict"');
};

const runPrepare = async (arguments_: string[]) => {
  const input = parseFlag(arguments_, "--input");
  const output = parseFlag(arguments_, "--output");
  if (arguments_.length > 0) throw new Error(`Unknown argument: ${arguments_[0]}`);
  if (!input || !output) throw new Error("prepare requires --input and --output");

  const contents = await Bun.file(input).text();
  const configuration = await prepareConfiguration(contents, process.cwd());
  await Bun.write(output, serializeConfiguration(configuration));
};

const runApplied = async (arguments_: string[]) => {
  const input = parseFlag(arguments_, "--input");
  if (arguments_.length > 0) throw new Error(`Unknown argument: ${arguments_[0]}`);
  if (!input) throw new Error("applied requires --input");

  const configuration = await prepareConfiguration(await Bun.file(input).text(), process.cwd());
  const ready = groupReadiness(configuration).filter(({ status }) => status === "ready");
  console.log("result:");
  console.log("  status: configured");
  console.log(`  variables: ${Object.keys(configuration).length}`);
  console.log(`providers[${ready.length}]{name,status}:`);
  for (const provider of ready) console.log(`  ${provider.name},ready`);
};

const proof = async (name: string, url: string, expected: number, init?: RequestInit) => {
  try {
    const response = await fetch(url, { ...init, signal: AbortSignal.timeout(5_000) });
    return { name, status: response.status === expected ? "passed" : `http-${response.status}` };
  } catch {
    return { name, status: "unreachable" };
  }
};

const runDoctor = async (arguments_: string[]) => {
  const strict = arguments_.includes("--strict");
  const unknown = arguments_.filter((argument) => argument !== "--strict");
  if (unknown.length > 0) throw new Error(`Unknown argument: ${unknown[0]}`);
  const authSiteURL = process.env.AUTH_SITE_URL;
  const convexURL = process.env.CONVEX_URL;
  if (!authSiteURL || !convexURL) throw new Error("CONVEX_URL and AUTH_SITE_URL are required");

  const deployed = parse(await Bun.stdin.text());
  const readiness = groupReadiness(deployed);
  const proofs = await Promise.all([
    proof("convex", `${convexURL}/version`, 200),
    proof("openid", `${authSiteURL}/.well-known/openid-configuration`, 200),
    proof("session", `${authSiteURL}/api/auth/get-session`, 200),
    proof("webhook-signature-guard", `${authSiteURL}/api/auth/stripe/webhook`, 400, {
      method: "POST",
      body: "{}",
    }),
  ]);
  const coreReady = proofs.every(({ status }) => status === "passed");
  const externalReady = externalConfigurationReady(readiness);

  console.log("auth:");
  console.log(`  core: ${coreReady ? "ready" : "failed"}`);
  console.log(`  external: ${externalReady ? "ready" : "incomplete"}`);
  console.log(`providers[${readiness.length}]{name,status,missing}:`);
  for (const provider of readiness) {
    console.log(
      `  ${provider.name},${provider.status},${toonString(provider.missing.join(" ") || "none")}`,
    );
  }
  console.log(`proofs[${proofs.length}]{name,status}:`);
  for (const check of proofs) console.log(`  ${check.name},${check.status}`);
  console.log(`official_docs[${Object.keys(officialDocs).length}]{area,url}:`);
  for (const [area, url] of Object.entries(officialDocs))
    console.log(`  ${area},${toonString(url)}`);
  if (!externalReady) {
    console.log("help[2]:");
    console.log('  "Copy `.env.auth.example` to `.env.auth.local` and fill one or more groups."');
    console.log('  "Run `devme run backend::auth-configure --output toon`."');
  }

  if (!coreReady || (strict && !externalReady)) process.exitCode = 1;
};

const main = async () => {
  const [command, ...arguments_] = Bun.argv.slice(2);
  if (command === "--help" || command === "help") return printHelp();
  if (command === "prepare") return runPrepare(arguments_);
  if (command === "applied") return runApplied(arguments_);
  if (command === "doctor") return runDoctor(arguments_);
  throw new Error(command ? `Unknown command: ${command}` : "A command is required");
};

if (import.meta.main) {
  try {
    await main();
  } catch (error) {
    printUsageError(error instanceof Error ? error.message : "Unknown auth configuration error");
    process.exitCode = 2;
  }
}
