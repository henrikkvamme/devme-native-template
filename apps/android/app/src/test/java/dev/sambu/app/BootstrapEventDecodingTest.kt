package dev.sambu.app

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
    assertEquals("Sambu backend is connected", event.message)
  }
}
