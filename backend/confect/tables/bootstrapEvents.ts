import { Table } from "@confect/server";
import * as Schema from "effect/Schema";

export default Table.make(() =>
  Schema.Struct({
    authenticated: Schema.optional(Schema.Boolean),
    client: Schema.Literals(["android", "ios", "test"]),
    message: Schema.String,
  }),
);
