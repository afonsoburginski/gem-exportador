package data

import io.ktor.client.*
import io.ktor.client.plugins.websocket.*
import io.ktor.websocket.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonArray
import model.DesenhoAutodesk
import util.logToFile

/**
 * Tipos de eventos realtime
 */
sealed class RealtimeEvent {
    data class Insert(val desenho: DesenhoAutodesk) : RealtimeEvent()
    data class Update(val desenho: DesenhoAutodesk) : RealtimeEvent()
    data class Delete(val id: String) : RealtimeEvent()
    data class InitialData(val desenhos: List<DesenhoAutodesk>) : RealtimeEvent()
    data class Error(val message: String) : RealtimeEvent()
    object Connected : RealtimeEvent()
    object Disconnected : RealtimeEvent()
}

/**
 * Mensagem recebida do WebSocket
 */
@Serializable
private data class WebSocketMessage(
    val type: String,
    val table: String? = null,
    val data: JsonElement? = null,  // Pode ser objeto ou array
    val id: String? = null
)

/**
 * Cliente WebSocket para sincronização em tempo real
 * Similar ao Supabase Realtime
 */
class RealtimeClient(
    private val serverUrl: String,
    private val repository: DesenhoRepository
) {
    private val json = Json { ignoreUnknownKeys = true }
    private val client = HttpClient {
        install(WebSockets)
    }
    
    private val _events = MutableSharedFlow<RealtimeEvent>(replay = 1)
    val events: SharedFlow<RealtimeEvent> = _events.asSharedFlow()
    
    private val _connectionState = MutableStateFlow(ConnectionState.DISCONNECTED)
    val connectionState: StateFlow<ConnectionState> = _connectionState.asStateFlow()
    
    private var reconnectJob: Job? = null
    private var wsSession: WebSocketSession? = null
    private var shouldReconnect = true
    
    enum class ConnectionState {
        DISCONNECTED,
        CONNECTING,
        CONNECTED,
        RECONNECTING
    }
    
    /**
     * Conecta ao servidor WebSocket
     */
    suspend fun connect() {
        if (_connectionState.value == ConnectionState.CONNECTED) return
        
        _connectionState.value = ConnectionState.CONNECTING
        
        try {
            client.webSocket(serverUrl) {
                wsSession = this
                _connectionState.value = ConnectionState.CONNECTED
                logToFile("INFO", "WebSocket conectado a $serverUrl")
                _events.emit(RealtimeEvent.Connected)
                
                // Solicita dados iniciais
                send(Frame.Text("""{"type":"subscribe","table":"desenhos"}"""))
                
                // Processa mensagens recebidas
                for (frame in incoming) {
                    when (frame) {
                        is Frame.Text -> {
                            val text = frame.readText()
                            processMessage(text)
                        }
                        is Frame.Close -> {
                            _connectionState.value = ConnectionState.DISCONNECTED
                            _events.emit(RealtimeEvent.Disconnected)
                        }
                        else -> {}
                    }
                }
            }
        } catch (e: CancellationException) {
            // Cancelamento normal (app fechando) - não logar como erro
            _connectionState.value = ConnectionState.DISCONNECTED
            throw e
        } catch (e: Exception) {
            _connectionState.value = ConnectionState.DISCONNECTED
            if (shouldReconnect) {
                logToFile("ERROR", "WebSocket falhou: ${e.message}")
                _events.emit(RealtimeEvent.Error("Erro de conexão: ${e.message}"))
                scheduleReconnect()
            }
        }
    }
    
    /**
     * Desconecta do servidor
     */
    suspend fun disconnect() {
        shouldReconnect = false
        reconnectJob?.cancel()
        reconnectJob = null
        try {
            wsSession?.close()
        } catch (_: Exception) { }
        wsSession = null
        _connectionState.value = ConnectionState.DISCONNECTED
        try {
            _events.emit(RealtimeEvent.Disconnected)
        } catch (_: Exception) { }
    }
    
    /**
     * Processa mensagem recebida do WebSocket
     */
    private suspend fun processMessage(text: String) {
        try {
            logToFile("DEBUG", "WebSocket recebeu: ${text.take(200)}...")
            val message = json.decodeFromString<WebSocketMessage>(text)
            
            when (message.type) {
                "initial" -> {
                    // Dados iniciais - lista completa (data é um array)
                    message.data?.let { dataElement ->
                        val dataStr = dataElement.toString()
                        val desenhos = json.decodeFromString<List<DesenhoAutodesk>>(dataStr)
                        logToFile("INFO", "WebSocket initial: ${desenhos.size} desenhos recebidos")
                        repository.upsertAll(desenhos)
                        _events.emit(RealtimeEvent.InitialData(desenhos))
                    }
                }
                "INSERT" -> {
                    message.data?.let { dataElement ->
                        val dataStr = dataElement.toString()
                        val desenho = json.decodeFromString<DesenhoAutodesk>(dataStr)
                        logToFile("INFO", "WebSocket INSERT: ${desenho.nomeArquivo} (${desenho.status})")
                        repository.upsert(desenho)
                        _events.emit(RealtimeEvent.Insert(desenho))
                    }
                }
                "UPDATE" -> {
                    message.data?.let { dataElement ->
                        val dataStr = dataElement.toString()
                        val desenho = json.decodeFromString<DesenhoAutodesk>(dataStr)
                        logToFile("INFO", "WebSocket UPDATE: ${desenho.nomeArquivo} -> ${desenho.status} (${desenho.progresso}%)")
                        repository.upsert(desenho)
                        _events.emit(RealtimeEvent.Update(desenho))
                    }
                }
                "DELETE" -> {
                    message.id?.let { id ->
                        logToFile("INFO", "WebSocket DELETE: $id")
                        repository.delete(id)
                        _events.emit(RealtimeEvent.Delete(id))
                    }
                }
                else -> {
                    logToFile("DEBUG", "WebSocket tipo desconhecido: ${message.type}")
                }
            }
        } catch (e: Exception) {
            logToFile("ERROR", "Erro ao processar mensagem WebSocket: ${e.message}")
            _events.emit(RealtimeEvent.Error("Erro ao processar mensagem: ${e.message}"))
        }
    }
    
    /**
     * Agenda reconexão após falha
     */
    private fun scheduleReconnect() {
        if (!shouldReconnect) return
        reconnectJob?.cancel()
        reconnectJob = CoroutineScope(Dispatchers.Default).launch {
            delay(5000) // Aguarda 5 segundos antes de reconectar
            if (shouldReconnect) {
                _connectionState.value = ConnectionState.RECONNECTING
                connect()
            }
        }
    }
}
