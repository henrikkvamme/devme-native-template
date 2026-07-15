package dev.starter.app

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Test

class BootstrapEventDecodingTest {
  @Test
  fun decodesDeployedWireFixture() {
    val fixture = checkNotNull(
      javaClass.classLoader?.getResource("bootstrap-event.json"),
    ).readText()

    val event = Json.decodeFromString<BootstrapEvent>(fixture)

    assertEquals("test", event.client)
    assertEquals("Backend is connected", event.message)
    assertEquals(true, event.authenticated)
  }
}
