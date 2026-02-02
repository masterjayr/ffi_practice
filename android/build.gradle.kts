import java.net.URL
import java.util.zip.ZipInputStream

group = "com.example.ffi_practice"
version = "0.0.4"

plugins {
    id("com.android.library")
}

android {
    namespace = "com.example.ffi_practice"
    compileSdk = 35

    defaultConfig {
        minSdk = 21
    }

    // 🔑 Load native libs from build/ (not src/)
    sourceSets["main"].jniLibs.srcDirs(
        layout.buildDirectory.dir("intermediates/ffi_practice_native")
    )
}

repositories {
    google()
    mavenCentral()
}

// -------------------------------------------------
// GitHub Release config
// -------------------------------------------------
val pluginVersion = project.version.toString()
val baseUrl =
    "https://github.com/masterjayr/ffi_practice/releases/download/v$pluginVersion"

val abis = listOf(
    "arm64-v8a",
    "armeabi-v7a",
    "x86_64"
)

val downloadsDir = layout.buildDirectory.dir("nativeDownloads")
val nativeOutDir = layout.buildDirectory.dir("intermediates/ffi_practice_native")

fun ensureDir(dir: File) {
    if (!dir.exists()) dir.mkdirs()
}

fun downloadIfMissing(url: String, outFile: File) {
    if (outFile.exists() && outFile.length() > 0) {
        println("✅ Cached: ${outFile.name}")
        return
    }

    ensureDir(outFile.parentFile)
    println("⬇️  Downloading $url")
    URL(url).openStream().use { input ->
        outFile.outputStream().use { output ->
            input.copyTo(output)
        }
    }
}

fun unzip(zip: File, dest: File) {
    ZipInputStream(zip.inputStream().buffered()).use { zis ->
        while (true) {
            val entry = zis.nextEntry ?: break
            val out = File(dest, entry.name)

            if (entry.isDirectory) {
                out.mkdirs()
            } else {
                ensureDir(out.parentFile)
                out.outputStream().use { zis.copyTo(it) }
            }
            zis.closeEntry()
        }
    }
}

tasks.register("prepareNativeLibs") {
    doLast {
        val downloadRoot = downloadsDir.get().asFile
        val nativeRoot = nativeOutDir.get().asFile

        ensureDir(downloadRoot)
        ensureDir(nativeRoot)

        abis.forEach { abi ->
            val zipName = "android-$abi.zip"
            val zipUrl = "$baseUrl/$zipName"
            val zipFile = File(downloadRoot, zipName)

            downloadIfMissing(zipUrl, zipFile)

            println("📦 Unzipping $zipName")
            unzip(zipFile, nativeRoot)

            // Sanity check
            val so = File(nativeRoot, "$abi/libffi_practice_native.so")
            if (!so.exists()) {
                error("❌ Missing libffi_practice_native.so for $abi")
            }
        }
    }
}

// Run before build
tasks.matching { it.name == "preBuild" }.configureEach {
    dependsOn("prepareNativeLibs")
}