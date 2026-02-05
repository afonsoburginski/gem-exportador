package util

import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.engine.cio.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.client.request.*
import io.ktor.serialization.kotlinx.json.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Resposta da API do GitHub Releases
 */
@Serializable
private data class GitHubRelease(
    val tag_name: String,
    val name: String? = null,
    val body: String? = null,
    val assets: List<GitHubAsset> = emptyList()
)

@Serializable
private data class GitHubAsset(
    val name: String,
    val browser_download_url: String
)

/**
 * Verifica atualizações disponíveis no GitHub Releases
 */
object UpdateChecker {
    // Configurar com o repositório correto
    private const val GITHUB_OWNER = "afonsoburginski"
    private const val GITHUB_REPO = "gem-exportador"
    
    private val client = HttpClient(CIO) {
        install(ContentNegotiation) {
            json(Json {
                ignoreUnknownKeys = true
                isLenient = true
            })
        }
    }
    
    /**
     * Verifica se há uma versão mais nova disponível no GitHub
     * @return VersionInfo se há atualização, null se não há ou erro
     */
    suspend fun checkForUpdate(): VersionInfo? {
        return try {
            val url = "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/releases/latest"
            val release: GitHubRelease = client.get(url) {
                header("Accept", "application/vnd.github.v3+json")
                header("User-Agent", "GemExportador/${AppVersion.current}")
            }.body()
            
            val remoteVersion = release.tag_name.removePrefix("v")
            
            if (AppVersion.isNewerVersion(remoteVersion)) {
                // Encontra o asset do instalador (.exe do NSIS ou .msi legado)
                val installerAsset = release.assets.find { 
                    it.name.endsWith("-setup.exe") || it.name.endsWith(".exe") || it.name.endsWith(".msi")
                }
                
                VersionInfo(
                    version = remoteVersion,
                    downloadUrl = installerAsset?.browser_download_url 
                        ?: "https://github.com/$GITHUB_OWNER/$GITHUB_REPO/releases/tag/${release.tag_name}",
                    releaseNotes = release.body ?: release.name ?: "Nova versão disponível",
                    mandatory = false
                )
            } else {
                null
            }
        } catch (e: Exception) {
            println("[UPDATE] Erro ao verificar atualizações: ${e.message}")
            null
        }
    }
    
    /**
     * Fecha o cliente HTTP
     */
    fun close() {
        client.close()
    }
}
