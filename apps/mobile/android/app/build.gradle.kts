import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun firstNonBlank(vararg values: String?): String? {
    for (value in values) {
        val trimmed = value?.trim()
        if (!trimmed.isNullOrEmpty()) return trimmed
    }
    return null
}

fun env(name: String): String? = System.getenv(name)

// MOBILE_KEYSTORE_PASSWORD, when set, is both the store password and the key password.
val mobilePassword = env("MOBILE_KEYSTORE_PASSWORD")?.trim()?.takeIf { it.isNotEmpty() }
val releaseStorePath = firstNonBlank(env("ANDROID_KEYSTORE_PATH"), keystoreProperties.getProperty("storeFile"))
val releaseStorePassword = mobilePassword ?: firstNonBlank(env("ANDROID_KEYSTORE_PASSWORD"), keystoreProperties.getProperty("storePassword"))
val releaseKeyPassword = mobilePassword ?: firstNonBlank(env("ANDROID_KEY_PASSWORD"), keystoreProperties.getProperty("keyPassword"))
val releaseKeyAlias = firstNonBlank(env("ANDROID_KEY_ALIAS"), keystoreProperties.getProperty("keyAlias"))
    ?: if (releaseStorePath != null) "sbexpress" else null
val hasReleaseKeystore = listOf(releaseStorePath, releaseStorePassword, releaseKeyAlias, releaseKeyPassword).all { it != null }

android {
    namespace = "com.sbexpress.sbexpress"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.sbexpress.sbexpress"
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

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                val path = releaseStorePath!!
                val store = File(path)
                storeFile = if (store.isAbsolute) store else rootProject.file(path)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Debug signing is only for non-release builds. A release task fails
            // in whenReady below when the release keystore is absent.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val releasing = allTasks.any { task ->
        val name = task.name
        name.contains("Release") && !name.contains("Debug")
    }
    if (releasing && !hasReleaseKeystore) {
        throw GradleException(
            "Release signing needs a keystore. Set android/key.properties (storeFile, storePassword, keyAlias, keyPassword) or ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, and ANDROID_KEY_PASSWORD. MOBILE_KEYSTORE_PASSWORD, when set, is used for both the store password and the key password. The alias defaults to sbexpress when a keystore path is set and no alias is given. Debug signing is not used for release. Do not commit the keystore or passwords.",
        )
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
