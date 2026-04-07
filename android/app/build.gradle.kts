plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.thesis.docease"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // FIX: Use simple string "17" to remove warning
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.thesis.docease"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // Using debug signing for now to allow the build to complete.
            // Replace with your release signing config later if you have one.
            signingConfig = signingConfigs.getByName("debug") 
            
            isMinifyEnabled = true 
            isShrinkResources = true
            
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
} // <--- This was the brace you were missing! It closes the "android" block.

flutter {
    source = "../.."
}