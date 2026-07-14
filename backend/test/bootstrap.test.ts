import { describe, it } from "@effect/vitest";
import { assertEquals } from "@effect/vitest/utils";
import * as Effect from "effect/Effect";

import refs from "../confect/_generated/refs";
import * as TestConfect from "./TestConfect";

describe("bootstrap contract", () => {
  it.effect("publishes a ping through the reactive list query", () =>
    Effect.gen(function* () {
      const backend = yield* TestConfect.TestConfect;

      assertEquals(yield* backend.query(refs.public.bootstrap.list, {}), []);

      yield* backend.mutation(refs.public.bootstrap.ping, {
        client: "test",
      });

      const events = yield* backend.query(refs.public.bootstrap.list, {});
      assertEquals(events.length, 1);
      assertEquals(events[0]?.client, "test");
      assertEquals(events[0]?.message, "Backend is connected");
    }).pipe(Effect.provide(TestConfect.layer())),
  );
});
