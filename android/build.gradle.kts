import java.net.URL
import java.util.zip.ZipInputStream

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

    // Make sure Gradle packages whatever ends up here
    sourceSets["main"].jniLibs.srcDirs("src/main/jniLibs")
}

repositories {
    google()
    mavenCentral()
}

// -----------------------------
// Config for GitHub Releases
// -----------------------------
val pluginVersion = project.version.toString()
val baseUrl = "https://github.com/masterjayr/ffi_practice/releases/download/v$pluginVersion"

val abis = listOf("arm64-v8a", "armeabi-v7a", "x86_64")

// We download zips into build/ so they’re cached between builds
val downloadsDir = layout.buildDirectory.dir("nativeDownloads")

fun ensureDirExists(dir: File) {
    if (!dir.exists()) dir.mkdirs()
}

fun downloadFileIfMissing(url: String, outFile: File) {
    if (outFile.exists() && outFile.length() > 0L) {
        println("✅ Already downloaded: ${outFile.name}")
        return
    }

    ensureDirExists(outFile.parentFile)
    println("⬇️  Downloading: $url")
    URL(url).openStream().use { input ->
        outFile.outputStream().use { output ->
            input.copyTo(output)
        }
    }
}

fun unzip(zipFile: File, destDir: File) {
    ensureDirExists(destDir)

    ZipInputStream(zipFile.inputStream().buffered()).use { zis ->
        while (true) {
            val entry = zis.nextEntry ?: break
            val outPath = File(destDir, entry.name)

            if (entry.isDirectory) {
                outPath.mkdirs()
            } else {
                ensureDirExists(outPath.parentFile)
                outPath.outputStream().use { fos ->
                    zis.copyTo(fos)
                }
            }
            zis.closeEntry()
        }
    }
}

tasks.register("prepareNativeLibs") {
    doLast {
        val jniLibsRoot = project.file("src/main/jniLibs")
        ensureDirExists(jniLibsRoot)

        val dlDir = downloadsDir.get().asFile
        ensureDirExists(dlDir)

        abis.forEach { abi ->
            // Your CI uploads: android-arm64-v8a.zip, android-armeabi-v7a.zip, android-x86_64.zip
            val zipName = "android-$abi.zip"
            val zipUrl = "$baseUrl/$zipName"
            val zipOut = File(dlDir, zipName)

            // Download zip if missing
            downloadFileIfMissing(zipUrl, zipOut)

            // Unzip into src/main/jniLibs/
            // (Your zip contains a top-level folder named "<abi>/", so this produces jniLibs/<abi>/*.so)
            println("📦 Unzipping $zipName -> ${jniLibsRoot.path}")
            unzip(zipOut, jniLibsRoot)

            // Sanity: ensure the plugin .so exists after unzip
            val expectedSo = File(jniLibsRoot, "$abi/libffi_practice_native.so")
            if (!expectedSo.exists()) {
                error(
                    "❌ Missing expected file after unzip: ${expectedSo.path}\n" +
                    "Check the contents of $zipName in your GitHub Release."
                )
            } else {
                println("✅ Found: ${expectedSo.path}")
            }
        }
    }
}

// Run before Android build so users only need `flutter pub get` + build.
tasks.matching { it.name == "preBuild" }.configureEach {
    dependsOn("prepareNativeLibs")
}