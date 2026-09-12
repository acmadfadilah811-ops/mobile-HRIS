plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.starphotoadvertising.hr"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }


    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // ID unik StarFoto -- diganti 2026-09-12 dari ID bawaan Horilla asli
        // (com.cybrosys.horilla_project). ID lama itu bentrok dengan aplikasi
        // Horilla resmi (kalau pernah/masih ada di HP dari Play Store publisher
        // Cybrosys) -- Android menampilkan tombol "Update" bukan "Install" dan
        // menolak pasang APK sideload ini karena tanda tangannya beda.
        applicationId = "com.starphotoadvertising.hr"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = 9
        versionName = "1.0.3"
    }

    buildTypes {
        getByName("release") {
            isShrinkResources = true // This requires isMinifyEnabled = true
            // TODO: ganti dengan kunci rilis sungguhan sebelum publish ke Play
            // Store -- ini pakai kunci debug bawaan Android supaya APK bisa
            // langsung di-install ke HP untuk pengujian (sebelumnya build
            // release sama sekali tidak ditandatangani -> "App not installed"
            // saat coba instal manual).
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
//    implementation("com.regula.face:api:6.1.3163")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // ML Kit text-recognition (Latin/Chinese/Devanagari/Japanese/Korean) DIHAPUS
    // 2026-09-12 -- tidak dipakai di kode native manapun (android/app/src),
    // sumber sisa ~27MB OCR native lib/model yang masih ada setelah
    // menghapus package Dart google_ml_kit (lihat pubspec.yaml).
    // Add your other dependencies here
}

flutter {
    source = "../.."
}
