import { createAuth } from "./betterAuth/auth";
import { internalAction, query } from "./_generated/server";

export const getLatestJwks = internalAction({
  args: {},
  handler: async (ctx) => {
    const auth = createAuth(ctx);
    return await auth.api.getLatestJwks();
  },
});

export const current = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return null;

    return {
      subject: identity.subject,
      name: identity.name,
      email: identity.email,
    };
  },
});
