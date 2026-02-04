package server

import io.ktor.server.application.*
import io.ktor.server.cio.*
import io.ktor.server.engine.*
import server.config.Config
import server.util.AppLog

private var serverInstance: CIOApplicationEngine? = null

fun main() {
    startEmbeddedServer(wait = true)
}

/**
 * Inicia o servidor Ktor. 
 * @param wait Se true, bloqueia a thread atual até o servidor parar.
 */
fun startEmbeddedServer(wait: Boolean = false) {
    if (serverInstance != null) {
        AppLog.info("Servidor já está rodando")
        return
    }
    
    AppLog.info("Iniciando servidor em ${Config.serverHost}:${Config.serverPort}")
    serverInstance = embeddedServer(CIO, port = Config.serverPort, host = Config.serverHost) {
        configureSerialization()
        configureStatusPages()
        configureWebSocket()
        configureRouting()
    }
    serverInstance!!.start(wait = wait)
}

/**
 * Para o servidor (se estiver rodando).
 */
fun stopEmbeddedServer() {
    serverInstance?.stop(1000, 2000)
    serverInstance = null
    AppLog.info("Servidor parado")
}
