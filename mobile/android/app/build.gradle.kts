import java.security.MessageDigest

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Every APK bundles byte-identical authoritative YAML, without requiring Python on the build host.
val syncOfflineConfigs by tasks.registering {
    val repository = rootProject.projectDir.parentFile.parentFile
    val destination = file("../../assets/configs")
    inputs.files(fileTree(repository.resolve("species_configs")), fileTree(repository.resolve("business_configs")))
    outputs.dir(destination)
    doLast {
        destination.mkdirs()
        val manifest = linkedMapOf<String, Map<String, String>>()
        for (folder in listOf("species_configs", "business_configs")) {
            repository.resolve(folder).listFiles { f -> f.extension == "yaml" }!!.sortedBy { it.name }.forEach { source ->
                val bytes = source.readBytes()
                val name = "$folder-${source.name}"
                destination.resolve(name).writeBytes(bytes)
                val digest = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
                manifest[name] = mapOf("source" to "$folder/${source.name}", "sha256" to digest)
            }
        }
        destination.resolve("manifest.json").writeText(groovy.json.JsonOutput.prettyPrint(groovy.json.JsonOutput.toJson(manifest)) + "\n")
    }
}
tasks.configureEach {
    if (name.startsWith("compileFlutterBuild")) dependsOn(syncOfflineConfigs)
}

android {
    namespace = "ai.biolivestock.biolivestock_capture"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ai.biolivestock.biolivestock_capture"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
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
