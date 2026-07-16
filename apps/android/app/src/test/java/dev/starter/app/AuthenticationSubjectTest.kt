package dev.starter.app

import org.junit.Assert.assertEquals
import org.junit.Test

class AuthenticationSubjectTest {
  @Test
  fun extractsDeletionIdentityFromConvexJwt() {
    val token = ConvexJwt("header.eyJzdWIiOiJ1c2VyLTEyMyJ9.signature")

    assertEquals("user-123", token.subject)
  }
}
