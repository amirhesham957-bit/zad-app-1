import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// ENABLE_KIDS_GEOFENCING (docs/agent/ZAD_LIVING_BRAIN.md): the same --dart-define
// lib/core/env/zad_env.dart reads. Flutter hands every define, env.json's too, to
// Gradle as base64 "KEY=VALUE" items in the dart-defines property. Off only when
// it says exactly false, so a build without it keeps the feature.
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.filter { it.isNotBlank() }
        ?.mapNotNull { item ->
            val pair = String(Base64.getDecoder().decode(item)).split("=", limit = 2)
            if (pair.size == 2) pair[0] to pair[1] else null
        }
        ?.toMap()
        ?: emptyMap()
val kidsGeofencing = dartDefines["ENABLE_KIDS_GEOFENCING"]?.trim()?.lowercase() != "false"

android {
    namespace = "com.aistudio.zad.wrtqvx"
    // Pinned, not flutter.compileSdkVersion: permission_handler_android 13
    // publishes AAR metadata demanding API 37 or later, and the build fails in
    // :app:checkDebugAarMetadata against the Flutter default.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications uses java.time on API levels without it.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.aistudio.zad.wrtqvx"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Play's monitoring declaration names this meta-data; without kids
        // geofencing the entry is renamed to something Play does not read.
        manifestPlaceholders["monitoringToolKey"] =
            if (kidsGeofencing) "isMonitoringTool" else "zad.kids_geofencing_off"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // The same desugaring library and version the Kotlin app ships.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
