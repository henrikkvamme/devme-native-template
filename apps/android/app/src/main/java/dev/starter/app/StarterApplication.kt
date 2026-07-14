package dev.starter.app

import android.app.Application
import dev.convex.android.ConvexClient

class StarterApplication : Application() {
  val backend: StarterBackend by lazy {
    LiveStarterConvexApi(ConvexClient(BuildConfig.CONVEX_URL))
  }
}
