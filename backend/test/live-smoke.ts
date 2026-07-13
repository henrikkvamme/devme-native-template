import { ConvexHttpClient } from "convex/browser";

import { api } from "../convex/_generated/api";

const deploymentUrl = process.env.CONVEX_URL;

if (deploymentUrl === undefined) {
  throw new Error("CONVEX_URL is required");
}

const client = new ConvexHttpClient(deploymentUrl);
const fixture = (await Bun.file(
  new URL("../../contracts/fixtures/bootstrap-event.json", import.meta.url),
).json()) as {
  client?: unknown;
  message?: unknown;
};

await client.mutation(api.bootstrap.ping, { client: "test" });
const events = await client.query(api.bootstrap.list, {});
const latest = events.at(0);

if (latest?.client !== "test" || latest.message !== "Sambu backend is connected") {
  throw new Error(`Unexpected bootstrap response: ${JSON.stringify(latest)}`);
}

if (latest.client !== fixture.client || latest.message !== fixture.message) {
  throw new Error("The deployed response no longer matches the shared native fixture");
}

process.stdout.write(`${JSON.stringify(latest)}\n`);
