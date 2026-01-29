group = "com.example.ffi_practice"
version = "0.0.1"

plugins {
    id("com.android.library")
}

android {
    namespace = "com.example.ffi_practice"
    compileSdk = 35

    defaultConfig {
        minSdk = 21
    }

    sourceSets["main"].jniLibs.srcDirs("src/main/jniLibs")
}

repositories {
    google()
    mavenCentral()
}

/**
 * Download prebuilt native binaries from GitHub Releases
 */
val pluginVersion = project.version.toString()
val baseUrl =
    "https://github.com/masterjayr/ffi_practice/releases/download/v$pluginVersion"

val abis = listOf(
    "arm64-v8a",
    "armeabi-v7a",
    "x86_64"
)

tasks.register("downloadNativeLibs") {
    doLast {
        abis.forEach { abi ->
            val outDir = file("${projectDir}/src/main/jniLibs/$abi")
            outDir.mkdirs()

            val soName = "libffi_practice_native.so"
            val remoteName = "libffi_practice_native-android-$abi.so"
            val url = "$baseUrl/$remoteName"
            val outFile = outDir.resolve(soName)

            if (!outFile.exists()) {
                println("Downloading $url")
                java.net.URL(url).openStream().use { input ->
                    outFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
            } else {
                println("Already exists: $outFile")
            }
        }
    }
}

tasks.named("preBuild") {
    dependsOn("downloadNativeLibs")
}