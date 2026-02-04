package util

import kotlinx.serialization.Serializable

/**
 * Informações sobre uma versão disponível para atualização
 */
@Serializable
data class VersionInfo(
    val version: String,
    val downloadUrl: String,
    val releaseNotes: String = "",
    val mandatory: Boolean = false
)

/**
 * Utilitários para gerenciamento de versões
 */
object AppVersion {
    // Versão atual do app (será lida do version.txt em runtime)
    var current: String = "1.0.0"
        private set
    
    /**
     * Inicializa a versão atual lendo do arquivo version.txt nos resources
     */
    fun init() {
        try {
            val versionText = Thread.currentThread().contextClassLoader
                ?.getResourceAsStream("version.txt")
                ?.bufferedReader()
                ?.readText()
                ?.trim()
            if (!versionText.isNullOrBlank()) {
                current = versionText
            }
        } catch (e: Exception) {
            // Mantém versão padrão
        }
    }
    
    /**
     * Compara duas versões semver
     * @return positivo se v1 > v2, negativo se v1 < v2, zero se iguais
     */
    fun compare(v1: String, v2: String): Int {
        val parts1 = v1.removePrefix("v").split(".").map { it.toIntOrNull() ?: 0 }
        val parts2 = v2.removePrefix("v").split(".").map { it.toIntOrNull() ?: 0 }
        
        val maxLen = maxOf(parts1.size, parts2.size)
        for (i in 0 until maxLen) {
            val p1 = parts1.getOrElse(i) { 0 }
            val p2 = parts2.getOrElse(i) { 0 }
            if (p1 != p2) return p1 - p2
        }
        return 0
    }
    
    /**
     * Verifica se há uma versão mais nova disponível
     */
    fun isNewerVersion(remoteVersion: String): Boolean {
        return compare(remoteVersion, current) > 0
    }
}
