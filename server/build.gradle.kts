plugins {
    kotlin("jvm")
    kotlin("plugin.serialization")
    application
}

kotlin {
    jvmToolchain(17)
}

application {
    mainClass.set("server.MainKt")
}

dependencies {
    implementation(project(":shared"))
    implementation("io.ktor:ktor-server-core:${rootProject.extra["ktor.version"]}")
    implementation("io.ktor:ktor-server-cio:${rootProject.extra["ktor.version"]}")
    implementation("io.ktor:ktor-server-content-negotiation:${rootProject.extra["ktor.version"]}")
    implementation("io.ktor:ktor-serialization-kotlinx-json:${rootProject.extra["ktor.version"]}")
    implementation("io.ktor:ktor-server-websockets:${rootProject.extra["ktor.version"]}")
    implementation("io.ktor:ktor-server-status-pages:${rootProject.extra["ktor.version"]}")
    implementation("io.ktor:ktor-utils:${rootProject.extra["ktor.version"]}")
    implementation("org.xerial:sqlite-jdbc:3.44.1.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:${rootProject.extra["coroutines.version"]}")
    implementation("io.github.cdimascio:dotenv-kotlin:6.4.1")
}
