import { describe, it } from "@effect/vitest";
import { assertEquals } from "@effect/vitest/utils";
import * as Effect from "effect/Effect";

import refs from "../confect/_generated/refs";
import * as TestConfect from "./TestConfect";

describe("bootstrap contract", () => {
  it.effect("reports whether each ping reached Convex with an authenticated identity", () =>
    Effect.gen(function* () {
      const backend = yield* TestConfect.TestConfect;

      assertEquals(yield* backend.query(refs.public.bootstrap.list, {}), []);

      yield* backend.mutation(refs.public.bootstrap.ping, {
        client: "test",
      });

      const authenticatedBackend = backend.withIdentity({
        subject: "starter-test-user",
      });
      yield* authenticatedBackend.mutation(refs.public.bootstrap.ping, {
        client: "test",
      });

      const events = yield* backend.query(refs.public.bootstrap.list, {});
      assertEquals(events.length, 2);
      assertEquals(events[0]?.authenticated, true);
      assertEquals(events[0]?.client, "test");
      assertEquals(events[0]?.message, "Backend is connected");
      assertEquals(events[1]?.authenticated, false);
    }).pipe(Effect.provide(TestConfect.layer())),
  );
});
