import { ConvexHttpClient } from "convex/browser";

import { api } from "../convex/_generated/api";

const deploymentUrl = process.env.CONVEX_URL;

if (deploymentUrl === undefined) {
  throw new Error("CONVEX_URL is required");
}

const events = await new ConvexHttpClient(deploymentUrl).query(api.bootstrap.list, {});
const latest = events.at(0);

process.stdout.write(`${latest?._id ?? ""}\t${latest?.client ?? ""}\n`);
