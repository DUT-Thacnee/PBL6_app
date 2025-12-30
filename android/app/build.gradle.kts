import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystoreCandidates = listOf("key.properties.local", "key.properties")
val keystorePropertiesFile = keystoreCandidates
    .map { rootProject.file(it) }
    .firstOrNull { it.exists() }
if (keystorePropertiesFile != null) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val keystoreFile = keystoreProperties["storeFile"]?.toString()?.let { rootProject.file(it) }
val hasReleaseKeystore = keystorePropertiesFile != null &&
    keystoreProperties["keyAlias"] != null &&
    keystoreProperties["keyPassword"] != null &&
    keystoreFile?.exists() == true &&
    keystoreProperties["storePassword"] != null


android {
    namespace = "com.dutthacnee.pbl6_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Unique application ID for Play Store
        applicationId = "com.dutthacnee.pbl6_app" // Thay đổi thành domain của bạn
        // Minimum SDK lowered for wider device support
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 1
        versionName = "1.0.0"
    }


    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreFile
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }


    buildTypes {
        release {
            // Release build for Play Store - disable minify to avoid R8 issues
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                logger.warn("Release keystore not configured. Falling back to debug keystore for testing builds.")
                // Sign with debug keystore so APK installs while waiting for a proper release key.
                signingConfig = signingConfigs.getByName("debug")
            }
        }
        debug {
            isDebuggable = true
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }
}

flutter {
    source = "../.."
}
