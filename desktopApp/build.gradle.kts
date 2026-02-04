import org.jetbrains.compose.desktop.application.dsl.TargetFormat

plugins {
    kotlin("multiplatform")
    id("org.jetbrains.compose")
}

kotlin {
    jvm()
    sourceSets {
        val jvmMain by getting  {
            dependencies {
                implementation(compose.desktop.currentOs)
                implementation(project(":shared"))
                implementation(project(":server"))  // Servidor embutido
                implementation("net.java.dev.jna:jna-platform:5.14.0")
                implementation("io.github.cdimascio:dotenv-kotlin:6.4.1")
            }
        }
    }
}

val appVersion: String by project.extra { project.property("app.version").toString() }
val appName: String by project.extra { project.property("app.name").toString() }

compose.desktop {
    application {
        mainClass = "MainKt"
        
        // Habilita hot reload para desenvolvimento
        jvmArgs("--add-opens", "java.desktop/sun.awt=ALL-UNNAMED")
        jvmArgs("--add-opens", "java.desktop/java.awt.peer=ALL-UNNAMED")

        buildTypes.release {
            proguard {
                configurationFiles.from(project.file("proguard-rules.pro"))
                obfuscate.set(false) // Não ofuscar, só otimizar e shrink
            }
        }

        nativeDistributions {
            targetFormats(TargetFormat.Dmg, TargetFormat.Msi, TargetFormat.Deb)
            packageName = appName
            packageVersion = appVersion
            description = "Exportador de desenhos Autodesk Inventor"
            vendor = "JhonRob"
            
            windows {
                iconFile.set(project.file("src/jvmMain/resources/favicon.ico"))
                menuGroup = appName
                upgradeUuid = "8F3B1A2C-5D4E-6F7A-8B9C-0D1E2F3A4B5C"
            }
        }
    }
}

// Task para gerar arquivo de versão acessível em runtime
tasks.register("generateVersionFile") {
    doLast {
        val versionFile = file("src/jvmMain/resources/version.txt")
        versionFile.parentFile.mkdirs()
        versionFile.writeText(appVersion)
    }
}

tasks.named("jvmProcessResources") {
    dependsOn("generateVersionFile")
}
