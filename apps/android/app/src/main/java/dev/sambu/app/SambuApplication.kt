package dev.sambu.app

import android.app.Application
import dev.convex.android.ConvexClient

class SambuApplication : Application() {
  val backend: SambuBackend by lazy {
    LiveSambuConvexApi(ConvexClient(BuildConfig.CONVEX_URL))
  }
}
