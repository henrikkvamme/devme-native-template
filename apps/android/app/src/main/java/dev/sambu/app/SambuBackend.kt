package dev.sambu.app

import dev.convex.android.ConvexClient
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class BootstrapEvent(
  @SerialName("_creationTime") val creationTime: Double,
  @SerialName("_id") val id: String,
  val client: String,
  val message: String,
)

interface SambuBackend {
  fun bootstrapEvents(): Flow<Result<List<BootstrapEvent>>>

  suspend fun ping()
}

class LiveSambuConvexApi(
  private val client: ConvexClient,
) : SambuBackend {
  private object Function {
    const val BootstrapList = "bootstrap:list"
    const val BootstrapPing = "bootstrap:ping"
  }

  override fun bootstrapEvents(): Flow<Result<List<BootstrapEvent>>> =
    client.subscribe(Function.BootstrapList)

  override suspend fun ping() {
    client.mutation<String>(
      Function.BootstrapPing,
      args = mapOf("client" to "android"),
    )
  }
}
