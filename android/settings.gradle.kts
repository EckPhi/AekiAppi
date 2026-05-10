pluginManagement {
    // Read flutter.sdk from local.properties
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").reader().use { reader ->
            properties.load(reader)
        }
        properties.getProperty("flutter.sdk") ?: error("flutter.sdk not set in local.properties")
    }
    
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    
    // Add Flutter tools gradle directory as a build
    includeBuild(file("$flutterSdkPath/packages/flutter_tools/gradle"))
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.6.0" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")

val localPropertiesFile = file("local.properties")
val properties = Properties()

check(localPropertiesFile.exists()) { "local.properties not found" }
localPropertiesFile.reader().use { reader ->
    properties.load(reader)
}

val flutterSdkPath: String = properties.getProperty("flutter.sdk")
check(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
