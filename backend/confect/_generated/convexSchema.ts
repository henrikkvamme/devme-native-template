import { defineSchema as $defineSchema } from "convex/server";

import bootstrapEvents from "./tables/bootstrapEvents";

export default $defineSchema({
  bootstrapEvents: bootstrapEvents.tableDefinition,
});
