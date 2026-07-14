plugins {
  id("com.android.application")
  id("org.jetbrains.kotlin.plugin.compose")
  id("org.jetbrains.kotlin.plugin.serialization")
}

val debugConvexUrl = providers
  .gradleProperty("convexUrl")
  .orElse("http://10.0.2.2:3210")

configurations.configureEach {
  // Convex 0.8.0 pins JNA 5.14.0, whose native binary cannot load on 16 KB
  // Android devices. JNA 5.19.1 ships a compatible aarch64 binary.
  resolutionStrategy.force("net.java.dev.jna:jna:5.19.1")
}

android {
  namespace = "dev.starter.app"
  compileSdk = 37

  defaultConfig {
    applicationId = "dev.starter.app"
    minSdk = 26
    targetSdk = 37
    versionCode = 1
    versionName = "1.0"

    testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
  }

  buildFeatures {
    buildConfig = true
    compose = true
  }

  buildTypes {
    debug {
      buildConfigField(
        "String",
        "CONVEX_URL",
        "\"${debugConvexUrl.get()}\"",
      )
    }
    release {
      buildConfigField(
        "String",
        "CONVEX_URL",
        "\"https://replace-before-release.invalid\"",
      )
      isMinifyEnabled = true
      isShrinkResources = true
      proguardFiles(
        getDefaultProguardFile("proguard-android-optimize.txt"),
        "proguard-rules.pro",
      )
    }
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }

  testOptions {
    unitTests.isReturnDefaultValues = true
  }

  lint {
    // AGP 9.2's verified compatibility matrix specifies Gradle 9.4.1.
    disable += "AndroidGradlePluginVersion"
  }

  sourceSets {
    getByName("test").resources.directories.add(
      "../../../contracts/fixtures",
    )
  }
}

dependencies {
  val composeBom = platform("androidx.compose:compose-bom:2026.06.00")

  implementation(composeBom)
  implementation("androidx.activity:activity-compose:1.13.0")
  implementation("androidx.compose.material:material-icons-extended")
  implementation("androidx.compose.material3:material3")
  implementation("androidx.compose.ui:ui")
  implementation("androidx.compose.ui:ui-tooling-preview")
  implementation("androidx.lifecycle:lifecycle-runtime-compose:2.11.0")
  implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.11.0")
  implementation("dev.convex:android-convexmobile:0.8.0@aar") {
    isTransitive = true
  }
  implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.11.0")

  debugImplementation(composeBom)
  debugImplementation("androidx.compose.ui:ui-tooling")

  testImplementation("junit:junit:4.13.2")
}
