plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.antigravity.valhalla.valhalla"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.antigravity.valhalla.valhalla"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // CI packages are explicitly unsigned until a release key is configured.
            // Preserve the existing local debug-key workflow for adb development.
            signingConfig = if (System.getenv("VALHALLA_CI_UNSIGNED") == "true") {
                null
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ServiceCompat.startForeground and NotificationCompat, used by
    // SshKeepAliveService. Declared explicitly rather than relying on the
    // Flutter embedding to bring it in transitively.
    implementation("androidx.core:core-ktx:1.13.1")
}
