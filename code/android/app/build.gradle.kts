plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.learningdart"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Enable desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.learningdart"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.10.1") // Ensure core-ktx is included
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:1.2.2") // Updated desugaring dependency
    implementation("com.google.firebase:firebase-analytics-ktx:21.2.0")
    implementation("com.google.firebase:firebase-auth-ktx:21.2.0")
    implementation("com.google.firebase:firebase-firestore-ktx:24.2.0")
    implementation("com.google.firebase:firebase-messaging-ktx:23.2.0")
    implementation("com.google.firebase:firebase-database-ktx:20.2.0")
    implementation("com.google.firebase:firebase-storage-ktx:20.2.0")
}

flutter {
    source = "../.."
}
