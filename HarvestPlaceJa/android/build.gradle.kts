plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.harvestplaceja.myapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.harvestplaceja.myapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        // Google Play requires this to increase for every new upload.
        versionCode = 3
        versionName = "1.0.2"
    }

    val cmKeystorePath = System.getenv("CM_KEYSTORE_PATH")
    val cmKeystorePassword = System.getenv("CM_KEYSTORE_PASSWORD")
    val cmKeyAlias = System.getenv("CM_KEY_ALIAS")
    val cmKeyPassword = System.getenv("CM_KEY_PASSWORD")

    val hasCodemagicSigning =
        !cmKeystorePath.isNullOrBlank() &&
        !cmKeystorePassword.isNullOrBlank() &&
        !cmKeyAlias.isNullOrBlank() &&
        !cmKeyPassword.isNullOrBlank()

    signingConfigs {
        create("release") {
            if (hasCodemagicSigning) {
                storeFile = file(cmKeystorePath!!)
                storePassword = cmKeystorePassword
                keyAlias = cmKeyAlias
                keyPassword = cmKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (hasCodemagicSigning) {
                println("Using Codemagic release signing config.")
                signingConfig = signingConfigs.getByName("release")
            } else {
                println("Codemagic release signing variables missing. Falling back to debug signing for local/test build only.")
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
