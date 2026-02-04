plugins {
    kotlin("multiplatform")
    kotlin("plugin.serialization")
    id("com.android.library")
    id("org.jetbrains.compose")
    id("app.cash.sqldelight")
}

kotlin {
    androidTarget()

    jvm("desktop")

    listOf(
        iosX64(),
        iosArm64(),
        iosSimulatorArm64()
    ).forEach { iosTarget ->
        iosTarget.binaries.framework {
            baseName = "shared"
            isStatic = true
        }
    }

    sourceSets {
        val commonMain by getting {
            dependencies {
                implementation(compose.runtime)
                implementation(compose.foundation)
                implementation(compose.material)
                @OptIn(org.jetbrains.compose.ExperimentalComposeLibrary::class)
                implementation(compose.components.resources)
                
                // Coroutines
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:${findProperty("coroutines.version")}")
                
                // Serialization
                implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:${findProperty("serialization.version")}")
                
                // Ktor Client (WebSocket)
                implementation("io.ktor:ktor-client-core:${findProperty("ktor.version")}")
                implementation("io.ktor:ktor-client-websockets:${findProperty("ktor.version")}")
                implementation("io.ktor:ktor-client-content-negotiation:${findProperty("ktor.version")}")
                implementation("io.ktor:ktor-serialization-kotlinx-json:${findProperty("ktor.version")}")
                
                // SQLDelight
                implementation("app.cash.sqldelight:coroutines-extensions:${findProperty("sqldelight.version")}")
            }
        }
        val androidMain by getting {
            dependencies {
                api("androidx.activity:activity-compose:1.7.2")
                api("androidx.appcompat:appcompat:1.6.1")
                api("androidx.core:core-ktx:1.10.1")
                
                // Ktor Android
                implementation("io.ktor:ktor-client-okhttp:${findProperty("ktor.version")}")
                
                // SQLDelight Android
                implementation("app.cash.sqldelight:android-driver:${findProperty("sqldelight.version")}")
            }
        }
        val iosX64Main by getting
        val iosArm64Main by getting
        val iosSimulatorArm64Main by getting
        val iosMain by creating {
            dependsOn(commonMain)
            iosX64Main.dependsOn(this)
            iosArm64Main.dependsOn(this)
            iosSimulatorArm64Main.dependsOn(this)
            dependencies {
                // Ktor iOS
                implementation("io.ktor:ktor-client-darwin:${findProperty("ktor.version")}")
                
                // SQLDelight iOS
                implementation("app.cash.sqldelight:native-driver:${findProperty("sqldelight.version")}")
            }
        }
        val desktopMain by getting {
            dependencies {
                implementation(compose.desktop.common)
                
                // Ktor Desktop (JVM)
                implementation("io.ktor:ktor-client-cio:${findProperty("ktor.version")}")
                
                // SQLDelight JVM
                implementation("app.cash.sqldelight:sqlite-driver:${findProperty("sqldelight.version")}")
                
                // Dotenv para ler .env
                implementation("io.github.cdimascio:dotenv-kotlin:6.4.1")
            }
        }
    }
}

// SQLDelight configuration
sqldelight {
    databases {
        create("GemDatabase") {
            packageName.set("com.jhonrob.gemexportador.db")
        }
    }
}

android {
    compileSdk = (findProperty("android.compileSdk") as String).toInt()
    namespace = "com.jhonrob.gemexportador.common"

    sourceSets["main"].manifest.srcFile("src/androidMain/AndroidManifest.xml")
    sourceSets["main"].res.srcDirs("src/androidMain/res")
    sourceSets["main"].resources.srcDirs("src/commonMain/resources")

    defaultConfig {
        minSdk = (findProperty("android.minSdk") as String).toInt()
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlin {
        jvmToolchain(17)
    }
}
