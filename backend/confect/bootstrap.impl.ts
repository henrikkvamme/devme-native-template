import { FunctionImpl, GroupImpl } from "@confect/server";
import * as Effect from "effect/Effect";
import * as Layer from "effect/Layer";

import databaseSchema from "./_generated/schema";
import { Auth, DatabaseReader, DatabaseWriter } from "./_generated/services";
import bootstrap from "./bootstrap.spec";

const list = FunctionImpl.make(databaseSchema, bootstrap, "list", () =>
  Effect.gen(function* () {
    const reader = yield* DatabaseReader;

    return yield* reader.table("bootstrapEvents").index("by_creation_time", "desc").take(20);
  }).pipe(Effect.orDie),
);

const ping = FunctionImpl.make(databaseSchema, bootstrap, "ping", ({ client }) =>
  Effect.gen(function* () {
    const auth = yield* Auth;
    const writer = yield* DatabaseWriter;
    const authenticated = yield* auth.getUserIdentity.pipe(
      Effect.as(true),
      Effect.catchTag("NoUserIdentityFoundError", () => Effect.succeed(false)),
    );

    return yield* writer.table("bootstrapEvents").insert({
      authenticated,
      client,
      message: "Backend is connected",
    });
  }).pipe(Effect.orDie),
);

export default GroupImpl.make(databaseSchema, bootstrap).pipe(
  Layer.provide(list),
  Layer.provide(ping),
  GroupImpl.finalize,
);
