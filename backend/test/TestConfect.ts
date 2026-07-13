/// <reference types="vite/client" />

import { TestConfect as TestConfect_ } from "@confect/test";

import convexSchema from "../confect/_generated/convexSchema";
import confectSchema from "../confect/_generated/schema";

export const TestConfect = TestConfect_.TestConfect<typeof confectSchema>();

export const layer = TestConfect_.layer(
  confectSchema,
  convexSchema,
  import.meta.glob("../convex/**/!(*.*.*)*.*s"),
);
