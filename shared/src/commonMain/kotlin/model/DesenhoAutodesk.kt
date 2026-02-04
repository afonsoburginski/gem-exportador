package model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Status possíveis de um desenho no processamento
 */
enum class DesenhoStatus(val value: String) {
    PENDENTE("pendente"),
    PROCESSANDO("processando"),
    CONCLUIDO("concluido"),
    CONCLUIDO_COM_ERROS("concluido_com_erros"),
    ERRO("erro"),
    CANCELADO("cancelado");
    
    companion object {
        fun fromString(value: String): DesenhoStatus {
            return entries.find { it.value.equals(value, ignoreCase = true) } ?: PENDENTE
        }
    }
}

/**
 * Arquivo processado/gerado
 */
@Serializable
data class ArquivoProcessado(
    val nome: String,
    val tipo: String,
    val caminho: String,
    val tamanho: Long
)

/**
 * Modelo principal de desenho
 * Formato compatível com o banco de dados real
 */
@Serializable
data class DesenhoAutodesk(
    val id: String,
    @SerialName("nome_arquivo") val nomeArquivo: String,
    val computador: String,
    @SerialName("caminho_destino") val caminhoDestino: String,
    val status: String,
    @SerialName("posicao_fila") val posicaoFila: Int? = null,
    @SerialName("horario_envio") val horarioEnvio: String,
    @SerialName("horario_atualizacao") val horarioAtualizacao: String,
    @SerialName("formatos_solicitados") val formatosSolicitadosJson: String? = null,
    @SerialName("arquivo_original") val arquivoOriginal: String? = null,
    @SerialName("arquivos_processados") val arquivosProcessadosJson: String? = null,
    val erro: String? = null,
    val progresso: Int = 0,
    val tentativas: Int = 0,
    @SerialName("arquivos_enviados_para_usuario") val arquivosEnviadosParaUsuario: Int = 0,
    @SerialName("cancelado_em") val canceladoEm: String? = null,
    @SerialName("criado_em") val criadoEm: String? = null,
    @SerialName("atualizado_em") val atualizadoEm: String? = null,
    @SerialName("pasta_processamento") val pastaProcessamento: String? = null
) {
    companion object {
        private val json = Json { ignoreUnknownKeys = true }
    }
    
    /**
     * Retorna o nome base do arquivo (sem extensão)
     */
    val nomeBase: String
        get() = nomeArquivo.substringBeforeLast(".")
    
    /**
     * Status como enum
     */
    val statusEnum: DesenhoStatus
        get() = DesenhoStatus.fromString(status)
    
    /**
     * Lista de formatos solicitados (parseado do JSON)
     */
    val formatosSolicitados: List<String>
        get() = try {
            formatosSolicitadosJson?.let { json.decodeFromString<List<String>>(it) } ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    
    /**
     * Lista de arquivos processados (parseado do JSON)
     */
    val arquivosProcessados: List<ArquivoProcessado>
        get() = try {
            arquivosProcessadosJson?.let { json.decodeFromString<List<ArquivoProcessado>>(it) } ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    
    /**
     * Pasta de origem (extraída do arquivo original)
     */
    val pastaOrigem: String?
        get() = arquivoOriginal?.substringBeforeLast("\\")?.substringBeforeLast("/")
    
    /**
     * Verifica se um formato já foi gerado
     */
    fun formatoJaGerado(formato: String): Boolean {
        val ext = formato.lowercase()
        return arquivosProcessados.any { arquivo ->
            arquivo.tipo.lowercase() == ext || arquivo.nome.lowercase().endsWith(".$ext")
        }
    }
}
