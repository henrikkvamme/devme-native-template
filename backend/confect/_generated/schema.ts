import { DatabaseSchema as $DatabaseSchema } from "@confect/server";

import bootstrapEvents from "./tables/bootstrapEvents";

const databaseSchema: $DatabaseSchema.DatabaseSchema<
  typeof bootstrapEvents
> = $DatabaseSchema.make({
  bootstrapEvents,
});

export default databaseSchema;
