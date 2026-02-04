package util

actual fun logToFile(level: String, message: String) {
    // Android: poderia usar Log.d/Log.e; por ora não grava em arquivo
}
