import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key for the Play Store. Its path and passwords live in
// android/key.properties, which is ignored by git and exists only on the
// machine that builds releases.
//
// Without it a release build stops with an error rather than quietly signing
// with the debug key: a debug-signed APK handed out directly could pass for
// a real release. To try a release build on your own phone without the key,
// opt in on purpose:
//   ORG_GRADLE_PROJECT_allowDebugSigning=true flutter run --release
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) FileInputStream(file).use { load(it) }
}
val hasUploadKey = keystoreProperties.getProperty("storeFile") != null
val allowDebugSigning = (findProperty("allowDebugSigning") as String?) == "true"

android {
    namespace = "com.sendagift.send_agift_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications needs java.time on older Androids.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.sendagift.send_agift_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasUploadKey) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = when {
                hasUploadKey -> signingConfigs.getByName("release")
                allowDebugSigning -> {
                    logger.warn("allowDebugSigning=true: signing this release with the DEBUG key. For testing only; never distribute it.")
                    signingConfigs.getByName("debug")
                }
                // No key and no opt-in: the check below stops the build.
                else -> null
            }
        }
    }
}

flutter {
    source = "../.."
}

// Fail closed: a release APK or app bundle is only built with the upload key
// (or the explicit testing opt-in above). Checked once the tasks are known,
// so debug builds and `flutter run` are never affected.
gradle.taskGraph.whenReady {
    val releasePackaging = allTasks.any { task ->
        task.project == project &&
            (task.name == "assembleRelease" || task.name == "bundleRelease" ||
                task.name == "packageRelease" || task.name == "packageReleaseBundle")
    }
    if (releasePackaging && !hasUploadKey && !allowDebugSigning) {
        throw GradleException(
            "Release signing key missing: add android/key.properties with the upload key. " +
                "For a local test build only, set ORG_GRADLE_PROJECT_allowDebugSigning=true.",
        )
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Push notifications need app/google-services.json from the Firebase
// console. Until it is added the app still builds; push is simply off.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
