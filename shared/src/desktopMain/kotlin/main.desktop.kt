import androidx.compose.desktop.ui.tooling.preview.Preview
import androidx.compose.runtime.Composable
import config.DesktopConfig
import data.DatabaseDriverFactory
import ui.components.UpdateState
import util.AppVersion
import util.UpdateChecker
import util.UpdateDownloader
import util.VersionInfo
import kotlin.system.exitProcess

actual fun getPlatformName(): String = "Desktop"
actual fun getServerBaseUrl(): String? = DesktopConfig.serverUrl
actual fun getSqliteDatabasePath(): String? = DatabaseDriverFactory.getConnectionInfo()

actual suspend fun checkForUpdates(): VersionInfo? {
    return try {
        UpdateChecker.checkForUpdate()
    } catch (e: kotlinx.coroutines.CancellationException) {
        // App fechando - não logar como erro
        null
    } catch (e: Exception) {
        println("[UPDATE] Erro ao verificar atualizações: ${e.message}")
        null
    }
}

actual suspend fun performUpdate(version: VersionInfo, onStateChange: (UpdateState) -> Unit) {
    try {
        onStateChange(UpdateState.Downloading(0))
        
        val msiFile = UpdateDownloader.downloadUpdate(version.downloadUrl) { progress ->
            onStateChange(UpdateState.Downloading(progress))
        }
        
        if (msiFile == null) {
            onStateChange(UpdateState.Error("Falha no download"))
            return
        }
        
        onStateChange(UpdateState.Installing)
        
        val success = UpdateDownloader.installUpdate(msiFile)
        if (success) {
            // Fecha o app para permitir a instalação
            exitProcess(0)
        } else {
            onStateChange(UpdateState.Error("Falha ao iniciar instalador"))
        }
    } catch (e: Exception) {
        onStateChange(UpdateState.Error(e.message ?: "Erro desconhecido"))
    }
}

@Composable 
fun MainView() {
    val databaseDriverFactory = DatabaseDriverFactory()
    App(databaseDriverFactory)
}

@Preview
@Composable
fun AppPreview() {
    val databaseDriverFactory = DatabaseDriverFactory()
    App(databaseDriverFactory)
}