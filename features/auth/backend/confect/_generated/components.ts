import { componentsGeneric } from "convex/server";

export type Components = {
  "betterAuth": import("../../convex/betterAuth/_generated/component.js").ComponentApi<"betterAuth">;
};

export const components: Components = componentsGeneric() as any;
