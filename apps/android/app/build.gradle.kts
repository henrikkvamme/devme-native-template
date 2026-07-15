plugins {
  id("com.android.application")
  id("org.jetbrains.kotlin.plugin.compose")
  id("org.jetbrains.kotlin.plugin.serialization")
}

val debugConvexUrl = providers
  .gradleProperty("convexUrl")
  .orElse("http://10.0.2.2:3210")
val debugAuthSiteUrl = providers
  .gradleProperty("authSiteUrl")
  .orElse("http://10.0.2.2:3211")
val releaseConvexUrl = providers
  .gradleProperty("releaseConvexUrl")
  .orElse("https://replace-before-release.invalid")
val releaseAuthSiteUrl = providers
  .gradleProperty("releaseAuthSiteUrl")
  .orElse("https://replace-before-release.invalid")
val releaseVersionCode = providers
  .gradleProperty("versionCode")
  .map(String::toInt)
  .orElse(1)
val releaseVersionName = providers
  .gradleProperty("versionName")
  .orElse("1.0")
val releaseApplicationId = "dev.starter.app"

val uploadKeystorePath = System.getenv("ANDROID_UPLOAD_KEYSTORE_PATH")
val uploadKeystorePassword = System.getenv("ANDROID_UPLOAD_KEYSTORE_PASSWORD")
val uploadKeyAlias = System.getenv("ANDROID_UPLOAD_KEY_ALIAS")
val uploadKeyPassword = System.getenv("ANDROID_UPLOAD_KEY_PASSWORD")
val releaseSigningValues = listOf(
  uploadKeystorePath,
  uploadKeystorePassword,
  uploadKeyAlias,
  uploadKeyPassword,
)
val releaseSigningConfigured = releaseSigningValues.all { !it.isNullOrBlank() }

require(releaseSigningValues.none { !it.isNullOrBlank() } || releaseSigningConfigured) {
  "Android release signing is partially configured. Set all ANDROID_UPLOAD_KEYSTORE_* variables."
}

configurations.configureEach {
  // Convex 0.8.0 pins JNA 5.14.0, whose native binary cannot load on 16 KB
  // Android devices. JNA 5.19.1 ships a compatible aarch64 binary.
  resolutionStrategy.force("net.java.dev.jna:jna:5.19.1")
}

val validateReleaseConfiguration by tasks.registering(Exec::class) {
  group = "verification"
  description = "Fail when Android release signing or endpoints are not configured"
  environment("RELEASE_APPLICATION_ID", releaseApplicationId)
  environment("RELEASE_CONVEX_URL", releaseConvexUrl.get())
  environment("RELEASE_AUTH_SITE_URL", releaseAuthSiteUrl.get())
  commandLine("bash", rootProject.file("../../tooling/android-release-preflight.sh"))
}

tasks.configureEach {
  if (name.contains("release", ignoreCase = true) && name != "validateReleaseConfiguration") {
    dependsOn(validateReleaseConfiguration)
  }
}

android {
  namespace = "dev.starter.app"
  compileSdk = 37

  signingConfigs {
    if (releaseSigningConfigured) {
      create("release") {
        storeFile = file(uploadKeystorePath!!)
        storePassword = uploadKeystorePassword
        keyAlias = uploadKeyAlias
        keyPassword = uploadKeyPassword
      }
    }
  }

  defaultConfig {
    applicationId = releaseApplicationId
    minSdk = 26
    targetSdk = 37
    versionCode = releaseVersionCode.get()
    versionName = releaseVersionName.get()

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
      buildConfigField(
        "String",
        "AUTH_SITE_URL",
        "\"${debugAuthSiteUrl.get()}\"",
      )
    }
    release {
      if (releaseSigningConfigured) {
        signingConfig = signingConfigs.getByName("release")
      }
      buildConfigField(
        "String",
        "CONVEX_URL",
        "\"${releaseConvexUrl.get()}\"",
      )
      buildConfigField(
        "String",
        "AUTH_SITE_URL",
        "\"${releaseAuthSiteUrl.get()}\"",
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
