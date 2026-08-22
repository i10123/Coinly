import java.io.FileInputStream
import java.util.Properties

val releaseKeyProperties = Properties()
val releaseKeyPropertiesFile = rootProject.file("key.properties")

val hasReleaseSigning = releaseKeyPropertiesFile.exists()

if (hasReleaseSigning) {
    releaseKeyProperties.load(FileInputStream(releaseKeyPropertiesFile))
}

if (!hasReleaseSigning) {
    tasks.configureEach {
        if (name.contains("release", ignoreCase = true)) {
            doFirst {
                throw GradleException(
                    "Release signing configuration is missing: android/key.properties",
                )
            }
        }
    }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.coinly"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.coinly"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.create("release") {
                    keyAlias = requireNotNull(
                        releaseKeyProperties.getProperty("keyAlias"),
                    )
                    keyPassword = requireNotNull(
                        releaseKeyProperties.getProperty("keyPassword"),
                    )
                    storeFile = file(requireNotNull(
                        releaseKeyProperties.getProperty("storeFile"),
                    ))
                    storePassword = requireNotNull(
                        releaseKeyProperties.getProperty("storePassword"),
                    )
                }
            }
        }
    }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
