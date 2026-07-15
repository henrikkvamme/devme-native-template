import { v } from "convex/values";

import { components } from "./_generated/api";
import { authComponent, createAuth } from "./betterAuth/auth";
import { internalAction, internalQuery, query } from "./_generated/server";

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

    const user = await authComponent.safeGetAuthUser(ctx);
    if (!user) return null;

    return {
      subject: identity.subject,
      name: user.name,
      email: user.email,
      image: user.image,
    };
  },
});

export const subscriptionForDiagnostics = internalQuery({
  args: { referenceId: v.string() },
  handler: async (ctx, args) => {
    const subscription = await ctx.runQuery(components.betterAuth.adapter.findOne, {
      model: "subscription",
      where: [{ field: "referenceId", value: args.referenceId }],
    });
    if (!subscription) return null;

    return {
      plan: subscription.plan,
      status: subscription.status,
      stripeSubscriptionId: subscription.stripeSubscriptionId,
    };
  },
});
