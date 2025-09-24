import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties
val keystoreProperties = Properties().apply {
    load(FileInputStream(rootProject.file("key.properties")))
}

android {
    namespace = "com.jvalmacis.coffeecore"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.14033849"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
        freeCompilerArgs = listOf("-Xlint:-options", "-Xlint:-deprecation")
    }

    defaultConfig {
        applicationId = "com.jvalmacis.coffeecore"
        minSdk = flutter.minSdkVersion.toInt()
        targetSdk = flutter.targetSdkVersion.toInt()
        versionCode = 6 // Incremented to avoid conflict with version 5
        versionName = "1.0.5"
        multiDexEnabled = true
        ndk {
            abiFilters.addAll(listOf("arm64-v8a", "x86_64")) // 64-bit ABIs for 16 KB compliance
        }
    }

    signingConfigs {
        create("release") {
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        jniLibs {
            pickFirsts.add("**/libc++_shared.so") // Common in Flutter and Firebase
            pickFirsts.add("**/libflutter.so")    // Flutter engine
            pickFirsts.add("**/libpdfium.so")     // For flutter_pdfview
        }
    }

    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.addAll(listOf("-Xlint:-options", "-Xlint:-deprecation"))
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:2.1.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(platform("com.google.firebase:firebase-bom:33.12.0"))
    implementation("com.google.firebase:firebase-messaging:24.1.0")
    implementation("com.google.firebase:firebase-analytics:22.1.0")
}