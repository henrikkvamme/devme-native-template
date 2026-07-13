import type { Document } from "@confect/server";
import type schemaDefinition from "./schema";

export type BootstrapEventsDoc = Document.Document<typeof schemaDefinition, "bootstrapEvents">;

export interface Docs {
  bootstrapEvents: BootstrapEventsDoc;
}
