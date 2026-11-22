plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.gateeaseapp"
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
        applicationId = "com.example.gateeaseapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val releaseSecrets = listOf(
        "GATEEASE_ANDROID_KEYSTORE", "GATEEASE_ANDROID_STORE_PASSWORD",
        "GATEEASE_ANDROID_KEY_ALIAS", "GATEEASE_ANDROID_KEY_PASSWORD",
    ).associateWith { providers.environmentVariable(it).orNull }

    signingConfigs {
        if (releaseSecrets.values.all { !it.isNullOrBlank() }) {
            create("release") {
                storeFile = file(releaseSecrets.getValue("GATEEASE_ANDROID_KEYSTORE")!!)
                storePassword = releaseSecrets.getValue("GATEEASE_ANDROID_STORE_PASSWORD")
                keyAlias = releaseSecrets.getValue("GATEEASE_ANDROID_KEY_ALIAS")
                keyPassword = releaseSecrets.getValue("GATEEASE_ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

flutter {
    source = "../.."
}
