import { FunctionSpec, GroupSpec } from "@confect/core";
import * as Schema from "effect/Schema";

import { Id } from "./_generated/id";
import bootstrapEvents from "./_generated/tables/bootstrapEvents";

export default GroupSpec.make()
  .addFunction(
    FunctionSpec.publicQuery({
      name: "list",
      args: () => Schema.Struct({}),
      returns: () => Schema.Array(bootstrapEvents.Doc),
    }),
  )
  .addFunction(
    FunctionSpec.publicMutation({
      name: "ping",
      args: () =>
        Schema.Struct({
          client: Schema.Literals(["android", "ios", "test"]),
        }),
      returns: () => Id("bootstrapEvents"),
    }),
  );
