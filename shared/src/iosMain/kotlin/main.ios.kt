import androidx.compose.ui.window.ComposeUIViewController
import data.DatabaseDriverFactory
import ui.components.UpdateState
import util.VersionInfo

actual fun getPlatformName(): String = "iOS"
actual fun getServerBaseUrl(): String? = null
actual fun getSqliteDatabasePath(): String? = null

// Auto-update não suportado no iOS (usa App Store)
actual suspend fun checkForUpdates(): VersionInfo? = null
actual suspend fun performUpdate(version: VersionInfo, onStateChange: (UpdateState) -> Unit) {
    // Não implementado para iOS
}

fun MainViewController() = ComposeUIViewController { 
    val databaseDriverFactory = DatabaseDriverFactory()
    App(databaseDriverFactory) 
}