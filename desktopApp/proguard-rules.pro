# ProGuard rules para GemExportador - OTIMIZADO

# Otimizações agressivas
-optimizationpasses 5
-allowaccessmodification
-mergeinterfacesaggressively

# Manter entry point
-keep class MainKt { public static void main(java.lang.String[]); }

# Compose - manter apenas o essencial
-keep class androidx.compose.runtime.** { *; }
-keep class androidx.compose.ui.** { *; }
-keep class androidx.compose.foundation.** { *; }
-keep class androidx.compose.material.** { *; }
-keep class org.jetbrains.skia.** { *; }
-keep class org.jetbrains.skiko.** { *; }

# Ktor - manter classes usadas
-keep class io.ktor.server.cio.** { *; }
-keep class io.ktor.server.engine.** { *; }
-keep class io.ktor.server.routing.** { *; }
-keep class io.ktor.server.websocket.** { *; }
-keep class io.ktor.client.** { *; }
-keep class io.ktor.http.** { *; }
-keep class io.ktor.websocket.** { *; }
-keep class io.ktor.serialization.** { *; }
-keep class io.ktor.utils.io.** { *; }

# Serialization - manter classes anotadas
-keepclassmembers class * {
    @kotlinx.serialization.Serializable *;
}
-keep,allowobfuscation @kotlinx.serialization.Serializable class *
-keepclassmembers @kotlinx.serialization.Serializable class * {
    *** Companion;
    *** INSTANCE;
    kotlinx.serialization.KSerializer serializer(...);
}

# Modelos do app
-keep class model.** { *; }
-keep class data.** { *; }
-keep class util.VersionInfo { *; }
-keep class util.AppVersion { *; }
-keep class server.** { *; }
-keep class config.** { *; }

# SQLDelight
-keep class app.cash.sqldelight.driver.jdbc.** { *; }
-keep class com.jhonrob.gemexportador.db.** { *; }

# JNA
-keep class com.sun.jna.** { *; }

# Dotenv
-keep class io.github.cdimascio.dotenv.** { *; }

# Warnings
-dontwarn kotlin.**
-dontwarn kotlinx.**
-dontwarn org.jetbrains.**
-dontwarn org.slf4j.**
-dontwarn javax.**
-dontwarn java.**
-dontwarn io.ktor.**

# Manter annotations necessárias
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,RuntimeVisibleAnnotations

# Enums
-keepclassmembers enum * { *; }
