import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.*
import androidx.compose.material.MaterialTheme
import androidx.compose.material.Text
import androidx.compose.material.darkColors
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.input.key.*
import androidx.compose.ui.unit.dp
import data.ApiClient
import data.DatabaseDriverFactory
import data.DesenhoRepository
import data.RealtimeClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import model.DesenhoAutodesk
import model.DesenhoStatus
import ui.components.DesenhoActions
import ui.components.DesenhosTable
import ui.components.UpdateDialog
import ui.components.UpdateState
import ui.theme.AppColors
import util.AppVersion
import util.VersionInfo
import util.getCurrentDateTime
import util.logToFile

/**
 * Inicializa o banco SQLite local.
 * NÃO cria seed - os dados vêm do servidor via WebSocket.
 */
private fun initializeSqlite(repository: DesenhoRepository) {
    val path = getSqliteDatabasePath()
    if (path != null) logToFile("INFO", "SQLite inicializado em $path")
}

/**
 * App principal com dados do SQLite
 */
@Composable
fun App(databaseDriverFactory: DatabaseDriverFactory) {
    val darkColorPalette = darkColors(
        primary = AppColors.Primary,
        primaryVariant = AppColors.PrimaryVariant,
        background = AppColors.Background,
        surface = AppColors.Surface
    )
    
    // Repositório do banco de dados (SQLite local)
    val repository = remember { DesenhoRepository(databaseDriverFactory) }
    val serverBaseUrl = getServerBaseUrl()
    val apiClient = if (serverBaseUrl != null) remember { ApiClient(serverBaseUrl) } else null

    // RealtimeClient para WebSocket
    val realtimeClient = if (serverBaseUrl != null) {
        val wsUrl = serverBaseUrl.replaceFirst("http", "ws") + "/ws"
        remember { RealtimeClient(wsUrl, repository) }
    } else null

    // Conecta ao WebSocket do servidor para sincronizar tabela em tempo real
    DisposableEffect(realtimeClient) {
        if (realtimeClient != null && serverBaseUrl != null) {
            logToFile("INFO", "Gem exportador (desktop) iniciado; servidor=$serverBaseUrl")
            val job = kotlinx.coroutines.CoroutineScope(Dispatchers.Default).launch {
                realtimeClient.connect()
            }
            onDispose {
                job.cancel()
                kotlinx.coroutines.runBlocking { 
                    try { realtimeClient.disconnect() } catch (_: Exception) {}
                }
            }
        } else {
            logToFile("INFO", "Gem exportador iniciado (modo offline/local)")
            onDispose { }
        }
    }

    // Garante o registro inicial no SQLite (sempre; com servidor o WebSocket "initial" pode depois sobrescrever)
    LaunchedEffect(Unit) {
        initializeSqlite(repository)
    }

    // Estado dos desenhos (observando do banco local; atualiza sozinho quando WebSocket envia INSERT/UPDATE)
    val desenhos by repository.observeAll().collectAsState(initial = emptyList())

    val scope = rememberCoroutineScope()
    
    // === AUTO-UPDATE ===
    var updateAvailable by remember { mutableStateOf<VersionInfo?>(null) }
    var showUpdateDialog by remember { mutableStateOf(false) }
    var updateDismissed by remember { mutableStateOf(false) }
    var updateState by remember { mutableStateOf<UpdateState>(UpdateState.Idle) }
    
    // Verifica se a fila está vazia (nenhum processando ou pendente)
    val queueEmpty by remember(desenhos) {
        derivedStateOf {
            desenhos.none { 
                it.statusEnum == DesenhoStatus.PROCESSANDO || 
                it.statusEnum == DesenhoStatus.PENDENTE 
            }
        }
    }
    
    // Verifica atualizações ao iniciar
    LaunchedEffect(Unit) {
        AppVersion.init()
        logToFile("INFO", "Versão atual: ${AppVersion.current}")
        
        // Aguarda 3 segundos antes de verificar (para não atrasar startup)
        delay(3000)
        
        checkForUpdates()?.let { version ->
            logToFile("INFO", "Atualização disponível: ${version.version}")
            updateAvailable = version
            showUpdateDialog = true
        }
    }
    
    // Quando a fila esvaziar e estamos aguardando, inicia o download
    LaunchedEffect(queueEmpty, updateState) {
        if (updateState == UpdateState.WaitingQueue && queueEmpty) {
            updateAvailable?.let { version ->
                performUpdate(version) { newState ->
                    updateState = newState
                }
            }
        }
    }
    
    // Dados vêm do servidor via WebSocket (não há sincronização local → servidor)

    // Ações: UI otimista - atualiza local IMEDIATAMENTE, depois envia para o servidor
    val actions = remember(apiClient, repository) {
        DesenhoActions(
            onRetry = { desenho ->
                logToFile("INFO", "Reenviar solicitado: ${desenho.nomeArquivo} (${desenho.id})")
                // UI OTIMISTA: atualiza local para processando para feedback visual azul imediato
                repository.updateStatus(desenho.id, "processando", getCurrentDateTime())
                scope.launch(Dispatchers.Default) {
                    if (apiClient != null) {
                        apiClient.retry(desenho.id) // servidor processa e WebSocket sincroniza
                    }
                }
            },
            onCancel = { desenho ->
                logToFile("INFO", "Cancelar solicitado: ${desenho.nomeArquivo} (${desenho.id})")
                // UI OTIMISTA: atualiza local imediatamente
                repository.updateStatus(desenho.id, "cancelado", getCurrentDateTime())
                scope.launch(Dispatchers.Default) {
                    if (apiClient != null) {
                        apiClient.cancelar(desenho.id)
                    }
                }
            },
            onDelete = { desenho ->
                logToFile("INFO", "Deletar solicitado: ${desenho.nomeArquivo} (${desenho.id})")
                // UI OTIMISTA: deleta local imediatamente
                repository.delete(desenho.id)
                scope.launch(Dispatchers.Default) {
                    if (apiClient != null) {
                        apiClient.delete(desenho.id)
                    }
                }
            }
        )
    }

    // Focus requester para capturar teclas (F5)
    val focusRequester = remember { FocusRequester() }
    
    // Estado de refresh (F5)
    var isRefreshing by remember { mutableStateOf(false) }
    
    MaterialTheme(colors = darkColorPalette) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(AppColors.Background)
                .padding(16.dp)
                .focusRequester(focusRequester)
                .focusable()
                .onKeyEvent { event ->
                    if (event.type == KeyEventType.KeyDown && event.key == Key.F5) {
                        logToFile("INFO", "F5 pressionado - refresh solicitado")
                        isRefreshing = true
                        scope.launch(Dispatchers.Default) {
                            realtimeClient?.refresh()
                            delay(1200) // tempo mínimo visual do loader
                            isRefreshing = false
                        }
                        true
                    } else {
                        false
                    }
                }
        ) {
            DesenhosTable(
                desenhos = desenhos,
                actions = actions,
                updateAvailable = if (updateDismissed) updateAvailable else null,
                onUpdateClick = { showUpdateDialog = true },
                modifier = Modifier.fillMaxSize(),
                isRefreshing = isRefreshing
            )
        }
        
        // Solicita foco ao iniciar para capturar teclas
        LaunchedEffect(Unit) {
            focusRequester.requestFocus()
        }
        
        // Dialog de atualização
        if (showUpdateDialog && updateAvailable != null) {
            UpdateDialog(
                versionInfo = updateAvailable!!,
                updateState = updateState,
                queueEmpty = queueEmpty,
                onUpdate = {
                    scope.launch {
                        if (queueEmpty) {
                            // Fila vazia - inicia download imediatamente
                            performUpdate(updateAvailable!!) { newState ->
                                updateState = newState
                            }
                        } else {
                            // Fila não vazia - aguarda esvaziar
                            updateState = UpdateState.WaitingQueue
                        }
                    }
                },
                onDismiss = {
                    if (updateState == UpdateState.Idle || updateState is UpdateState.Error) {
                        showUpdateDialog = false
                        updateDismissed = true
                    }
                }
            )
        }
    }
}

expect fun getPlatformName(): String
/** URL base do servidor (ex: http://localhost:8080). Se null, usa só SQLite local. */
expect fun getServerBaseUrl(): String?
/** Caminho do arquivo SQLite em disco (desktop); null em outras plataformas. */
expect fun getSqliteDatabasePath(): String?
/** Verifica se há atualizações disponíveis */
expect suspend fun checkForUpdates(): VersionInfo?
/** Executa o processo de atualização (download + instalação) */
expect suspend fun performUpdate(version: VersionInfo, onStateChange: (UpdateState) -> Unit)
