# ProGuard rules para GemExportador
# Mantém tamanho reduzido sem quebrar funcionalidades

# Manter classes principais
-keep class MainKt { *; }
-keep class MainKt$* { *; }

# Manter Compose
-keep class androidx.compose.** { *; }
-keep class org.jetbrains.skia.** { *; }
-keep class org.jetbrains.skiko.** { *; }

# Manter Ktor (servidor e cliente)
-keep class io.ktor.** { *; }
-keep class io.ktor.server.** { *; }
-keep class io.ktor.client.** { *; }
-keep class io.ktor.serialization.** { *; }
-keep class io.ktor.http.** { *; }
-keep class io.ktor.websocket.** { *; }
-keep class io.ktor.utils.** { *; }

# Manter kotlinx.serialization
-keep class kotlinx.serialization.** { *; }
-keepclassmembers class * {
    @kotlinx.serialization.Serializable *;
}
-keepclassmembers @kotlinx.serialization.Serializable class * {
    *;
}

# Manter classes de modelo (serialização)
-keep class model.** { *; }
-keep class data.** { *; }
-keep class util.** { *; }
-keep class ui.** { *; }
-keep class config.** { *; }
-keep class server.** { *; }

# Manter SQLDelight
-keep class app.cash.sqldelight.** { *; }
-keep class com.jhonrob.gemexportador.db.** { *; }

# Manter JNA para dark title bar
-keep class com.sun.jna.** { *; }
-keep class com.sun.jna.platform.** { *; }

# Manter SLF4J
-keep class org.slf4j.** { *; }
-dontwarn org.slf4j.**

# Manter dotenv
-keep class io.github.cdimascio.** { *; }

# Configurações gerais
-dontoptimize
-dontobfuscate
-dontwarn kotlin.**
-dontwarn kotlinx.**
-dontwarn org.jetbrains.**
-dontwarn javax.**
-dontwarn java.**

# Manter annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Manter enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Manter Kotlin metadata
-keep class kotlin.Metadata { *; }
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}
