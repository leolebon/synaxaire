plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "org.synaxaire.calendrier"
    compileSdk = 35

    defaultConfig {
        applicationId = "org.synaxaire.calendrier"
        minSdk = 26
        targetSdk = 35
        versionCode = 2
        versionName = "2.0"
    }

    // Clé de signature fournie avec le projet : permet d'installer les mises à jour
    // par-dessus l'ancienne version. Usage personnel uniquement (pas pour le Play Store).
    signingConfigs {
        create("shared") {
            storeFile = file("synaxaire.keystore")
            storePassword = "synaxaire"
            keyAlias = "synaxaire"
            keyPassword = "synaxaire"
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("shared")
        }
        debug {
            signingConfig = signingConfigs.getByName("shared")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
    }
    lint {
        abortOnError = false
        checkReleaseBuilds = false
    }

    // Les données (synaxaire.json, i18n.json) sont partagées avec l'app iPhone : dossier ../../Shared.
    sourceSets["main"].assets.srcDir(layout.buildDirectory.dir("generated/sharedAssets"))
}

val copySharedAssets by tasks.registering(Copy::class) {
    from(rootProject.file("../Shared")) { include("*.json") }
    into(layout.buildDirectory.dir("generated/sharedAssets"))
}
tasks.named("preBuild") { dependsOn(copySharedAssets) }

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.10.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-core")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.glance:glance-appwidget:1.1.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("com.google.mlkit:translate:17.0.3")
}
