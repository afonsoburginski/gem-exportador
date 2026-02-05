package ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.input.pointer.PointerButton
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import model.DesenhoAutodesk
import model.DesenhoStatus
import ui.theme.AppColors
import util.VersionInfo
import util.openInExplorer

/**
 * Callback para ações do context menu
 */
data class DesenhoActions(
    val onRetry: (DesenhoAutodesk) -> Unit = {},
    val onCancel: (DesenhoAutodesk) -> Unit = {}
)

/**
 * Componente de tabela para exibir desenhos
 */
@Composable
fun DesenhosTable(
    desenhos: List<DesenhoAutodesk>,
    modifier: Modifier = Modifier,
    actions: DesenhoActions = DesenhoActions(),
    updateAvailable: VersionInfo? = null,
    onUpdateClick: () -> Unit = {}
) {
    // Estado para mostrar/ocultar concluídos
    var mostrarConcluidos by remember { mutableStateOf(false) }
    
    // Separar desenhos por categoria
    val (emFila, concluidos, comProblema) = remember(desenhos) {
        val fila = mutableListOf<DesenhoAutodesk>()
        val ok = mutableListOf<DesenhoAutodesk>()
        val problema = mutableListOf<DesenhoAutodesk>()
        
        desenhos.forEach { d ->
            when (d.statusEnum) {
                DesenhoStatus.PROCESSANDO, DesenhoStatus.PENDENTE -> fila.add(d)
                DesenhoStatus.CONCLUIDO -> ok.add(d)
                DesenhoStatus.CONCLUIDO_COM_ERROS -> problema.add(d) // Parcial fica visível para o usuário poder reenviar
                DesenhoStatus.ERRO, DesenhoStatus.CANCELADO -> problema.add(d)
            }
        }
        
        // Ordenar fila: processando primeiro, depois pendentes por posição
        fila.sortWith(compareBy(
            { if (it.statusEnum == DesenhoStatus.PROCESSANDO) 0 else 1 },
            { it.posicaoFila ?: Int.MAX_VALUE }
        ))
        
        Triple(fila, ok, problema)
    }
    
    // Lista final: fila → erros/cancelados → concluídos (no final)
    val desenhosExibidos = remember(emFila, concluidos, comProblema, mostrarConcluidos) {
        val lista = mutableListOf<DesenhoAutodesk>()
        lista.addAll(emFila)
        lista.addAll(comProblema)
        if (mostrarConcluidos) {
            lista.addAll(concluidos)
        }
        lista
    }
    
    BoxWithConstraints(modifier = modifier.fillMaxSize()) {
        // Layout compacto para telas < 700dp de largura
        val isCompact = maxWidth < 700.dp
        
        Column(
            modifier = Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(4.dp))
                .background(AppColors.Surface)
                .border(1.dp, AppColors.Border, RoundedCornerShape(4.dp))
        ) {
            // Toolbar
            Toolbar(
                emFila = emFila.size,
                concluidos = concluidos.size,
                erros = comProblema.count { it.statusEnum == DesenhoStatus.ERRO },
                cancelados = comProblema.count { it.statusEnum == DesenhoStatus.CANCELADO },
                mostrarConcluidos = mostrarConcluidos,
                onToggleConcluidos = { mostrarConcluidos = !mostrarConcluidos },
                updateAvailable = updateAvailable,
                onUpdateClick = onUpdateClick,
                isCompact = isCompact
            )
            
            Divider(color = AppColors.Border, thickness = 1.dp)
            
            // Header
            TableHeader(isCompact = isCompact)
            
            Divider(color = AppColors.Border, thickness = 1.dp)
            
            // Rows
            if (desenhosExibidos.isEmpty()) {
                EmptyState()
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize()
                ) {
                    items(desenhosExibidos, key = { it.id }) { desenho ->
                        TableRowWithContextMenu(
                            desenho = desenho,
                            actions = actions,
                            isCompact = isCompact
                        )
                        Divider(color = AppColors.Border, thickness = 1.dp)
                    }
                }
            }
        }
    }
}

@Composable
private fun Toolbar(
    emFila: Int,
    concluidos: Int,
    erros: Int,
    cancelados: Int,
    mostrarConcluidos: Boolean,
    onToggleConcluidos: () -> Unit,
    updateAvailable: VersionInfo? = null,
    onUpdateClick: () -> Unit = {},
    isCompact: Boolean = false
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.SurfaceVariant)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Lado esquerdo: contadores
        Row(
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Em fila
            StatusBadge(
                label = "Em fila",
                count = emFila,
                color = AppColors.BadgeBlue
            )
            
            // Erros (se houver)
            if (erros > 0) {
                StatusBadge(
                    label = "Erros",
                    count = erros,
                    color = AppColors.BadgeRed
                )
            }
            
            // Cancelados (se houver)
            if (cancelados > 0) {
                StatusBadge(
                    label = "Cancelados",
                    count = cancelados,
                    color = AppColors.BadgeOrange
                )
            }
        }
        
        // Lado direito: botão de update (se disponível) e toggle concluídos
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Botão de atualização (se há update disponível e usuário fechou o dialog)
            if (updateAvailable != null) {
                UpdateButton(onClick = onUpdateClick)
            }
            
            // Toggle concluídos
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(4.dp))
                    .background(if (mostrarConcluidos) AppColors.BadgeGreenBg else AppColors.BadgeGrayBg)
                    .border(
                        1.dp,
                        if (mostrarConcluidos) AppColors.BadgeGreen.copy(alpha = 0.5f) else AppColors.Border,
                        RoundedCornerShape(4.dp)
                    )
                    .clickable { onToggleConcluidos() }
                    .padding(horizontal = 12.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                if (mostrarConcluidos) {
                    Icon(
                        imageVector = Icons.Filled.Check,
                        contentDescription = "Ativo",
                        tint = AppColors.BadgeGreen,
                        modifier = Modifier.size(14.dp)
                    )
                }
                Text(
                    text = "Concluídos ($concluidos)",
                    color = if (mostrarConcluidos) AppColors.BadgeGreen else AppColors.TextSecondary,
                    fontSize = 13.sp,
                    fontWeight = if (mostrarConcluidos) FontWeight.Medium else FontWeight.Normal
                )
            }
        }
    }
}

@Composable
private fun StatusBadge(
    label: String,
    count: Int,
    color: androidx.compose.ui.graphics.Color
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = label,
            color = AppColors.TextSecondary,
            fontSize = 12.sp
        )
        Text(
            text = count.toString(),
            color = color,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
private fun TableHeader(isCompact: Boolean = false) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.SurfaceVariant)

            .padding(horizontal = if (isCompact) 8.dp else 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        HeaderCell(text = "ARQUIVO", modifier = Modifier.weight(1.0f))
        HeaderCell(text = "FORMATOS", modifier = Modifier.weight(if (isCompact) 1.0f else 1.5f))
        if (!isCompact) {
            HeaderCell(text = "COMPUTADOR", modifier = Modifier.weight(0.8f))
            HeaderCell(text = "PASTA", modifier = Modifier.weight(1.8f))
            HeaderCell(text = "ENVIADO", modifier = Modifier.weight(0.8f))
        }
        // Em modo compacto, usa ícone em vez de texto para AÇÕES
        HeaderCell(text = if (isCompact) "" else "AÇÕES", modifier = Modifier.weight(if (isCompact) 0.2f else 0.3f))
    }
}

@Composable
private fun HeaderCell(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        color = AppColors.TextSecondary,
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = 0.5.sp,
        modifier = modifier
    )
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
private fun TableRowWithContextMenu(
    desenho: DesenhoAutodesk,
    actions: DesenhoActions,
    isCompact: Boolean = false
) {
    var showMenu by remember { mutableStateOf(false) }
    
    Box {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.Surface)
                .clickable(
                    interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() },
                    indication = null
                ) { }
                .pointerInput(Unit) {
                    awaitPointerEventScope {
                        while (true) {
                            val event = awaitPointerEvent()
                            if (event.type == PointerEventType.Press &&
                                event.button == PointerButton.Secondary) {
                                showMenu = true
                            }
                        }
                    }
                }
                .padding(horizontal = if (isCompact) 8.dp else 16.dp, vertical = if (isCompact) 10.dp else 14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            ArquivoCell(desenho, modifier = Modifier.weight(1.0f), isCompact = isCompact)
            FormatosCell(desenho, modifier = Modifier.weight(if (isCompact) 1.0f else 1.5f), isCompact = isCompact)
            if (!isCompact) {
                ComputadorCell(desenho.computador, modifier = Modifier.weight(0.8f))
                PastaCell(desenho, modifier = Modifier.weight(1.8f))
                EnviadoCell(desenho.horarioEnvio, modifier = Modifier.weight(0.8f), isCompact = isCompact)
            }
            AcoesCell(
                desenho = desenho,
                actions = actions,
                modifier = Modifier.weight(if (isCompact) 0.2f else 0.3f),
                isCompact = isCompact,
                showMenuExternal = showMenu,
                onMenuDismiss = { showMenu = false }
            )
        }
    }
}

@Composable
private fun AcoesCell(
    desenho: DesenhoAutodesk,
    actions: DesenhoActions,
    modifier: Modifier = Modifier,
    isCompact: Boolean = false,
    showMenuExternal: Boolean = false,
    onMenuDismiss: () -> Unit = {}
) {
    var showDropdown by remember { mutableStateOf(false) }
    val status = desenho.statusEnum
    val podeRetry = status == DesenhoStatus.ERRO || status == DesenhoStatus.CANCELADO || status == DesenhoStatus.CONCLUIDO_COM_ERROS
    val podeCancelar = status == DesenhoStatus.PENDENTE || status == DesenhoStatus.PROCESSANDO
    
    // Sincroniza com menu externo (botão direito)
    LaunchedEffect(showMenuExternal) {
        if (showMenuExternal) showDropdown = true
    }

    Box(
        modifier = modifier,
        contentAlignment = Alignment.CenterStart
    ) {
        // Botão 3 pontinhos
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(6.dp))
                .background(AppColors.SurfaceVariant)
                .border(1.dp, AppColors.Border, RoundedCornerShape(6.dp))
                .clickable { showDropdown = true }
                .pointerHoverIcon(PointerIcon.Hand)
                .padding(horizontal = 10.dp, vertical = 6.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "⋮",
                color = AppColors.TextPrimary,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
        }
        
        // Menu dropdown estilizado
        DropdownMenu(
            expanded = showDropdown,
            onDismissRequest = { 
                showDropdown = false
                onMenuDismiss()
            },
            modifier = Modifier
                .background(AppColors.Surface)
                .border(1.dp, AppColors.Border, RoundedCornerShape(8.dp))
                .widthIn(min = 220.dp)
        ) {
            // Header com nome do arquivo
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppColors.SurfaceVariant)
                    .padding(horizontal = 12.dp, vertical = 8.dp)
            ) {
                Text(
                    text = desenho.nomeArquivo,
                    color = AppColors.TextPrimary,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            
            Divider(color = AppColors.Border)
            
            // Data de envio
            val horarioFormatado = desenho.horarioEnvio
                .replace(Regex(":\\d{2}\\..*"), "")
                .replace(Regex("\\+\\d{2}$"), "")
            
            MenuItemStyled(
                icon = Icons.Filled.Schedule,
                label = "Enviado",
                value = horarioFormatado.ifEmpty { "—" },
                onClick = { showDropdown = false; onMenuDismiss() }
            )
            
            // Computador
            if (desenho.computador.isNotEmpty()) {
                MenuItemStyled(
                    icon = Icons.Filled.Computer,
                    label = "Computador",
                    value = desenho.computador,
                    onClick = { showDropdown = false; onMenuDismiss() }
                )
            }
            
            Divider(color = AppColors.Border, modifier = Modifier.padding(vertical = 4.dp))
            
            // Origem
            desenho.pastaOrigem?.takeIf { it.isNotEmpty() }?.let { origem ->
                MenuItemStyled(
                    icon = Icons.Filled.FolderOpen,
                    label = "Abrir Origem",
                    value = truncatePath(origem, 35),
                    isClickable = true,
                    onClick = { 
                        openInExplorer(origem)
                        showDropdown = false
                        onMenuDismiss()
                    }
                )
            }
            
            // Destino
            desenho.caminhoDestino.takeIf { it.isNotEmpty() }?.let { destino ->
                MenuItemStyled(
                    icon = Icons.Filled.Folder,
                    label = "Abrir Destino",
                    value = truncatePath(destino, 35),
                    isClickable = true,
                    onClick = { 
                        openInExplorer(destino)
                        showDropdown = false
                        onMenuDismiss()
                    }
                )
            }
            
            // Ações
            if (podeRetry || podeCancelar) {
                Divider(color = AppColors.Border, modifier = Modifier.padding(vertical = 4.dp))
                
                if (podeRetry) {
                    MenuItemStyled(
                        icon = Icons.Filled.Refresh,
                        label = "Reenviar",
                        isAction = true,
                        onClick = {
                            actions.onRetry(desenho)
                            showDropdown = false
                            onMenuDismiss()
                        }
                    )
                }
                if (podeCancelar) {
                    MenuItemStyled(
                        icon = Icons.Filled.Close,
                        label = "Cancelar",
                        isAction = true,
                        isDestructive = true,
                        onClick = {
                            actions.onCancel(desenho)
                            showDropdown = false
                            onMenuDismiss()
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun MenuItemStyled(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    value: String? = null,
    isClickable: Boolean = false,
    isAction: Boolean = false,
    isDestructive: Boolean = false,
    onClick: () -> Unit
) {
    val iconColor = when {
        isDestructive -> AppColors.BadgeRed
        isClickable -> AppColors.Primary
        isAction -> AppColors.TextPrimary
        else -> AppColors.TextSecondary
    }
    
    val textColor = when {
        isDestructive -> AppColors.BadgeRed
        isClickable -> AppColors.Primary
        isAction -> AppColors.TextPrimary
        else -> AppColors.TextPrimary // Cor mais clara para valores
    }
    
    val labelColor = when {
        isAction -> textColor
        else -> AppColors.TextSecondary // Cor mais visível para labels
    }
    
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(4.dp))
            .clickable(onClick = onClick)
            .pointerHoverIcon(if (isClickable || isAction) PointerIcon.Hand else PointerIcon.Default)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = iconColor,
            modifier = Modifier.size(16.dp)
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = label,
                color = labelColor,
                fontSize = if (isAction) 13.sp else 11.sp,
                fontWeight = if (isAction) FontWeight.Medium else FontWeight.Normal
            )
            if (value != null) {
                Text(
                    text = value,
                    color = textColor,
                    fontSize = 12.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    textDecoration = if (isClickable) TextDecoration.Underline else TextDecoration.None
                )
            }
        }
        if (isClickable) {
            Icon(
                imageVector = Icons.Filled.OpenInNew,
                contentDescription = "Abrir",
                tint = AppColors.TextSecondary,
                modifier = Modifier.size(14.dp)
            )
        }
    }
}

@Composable
private fun ArquivoCell(desenho: DesenhoAutodesk, modifier: Modifier = Modifier, isCompact: Boolean = false) {
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        val status = desenho.statusEnum
        
        // Posição na fila (se pendente ou processando)
        if ((status == DesenhoStatus.PENDENTE || status == DesenhoStatus.PROCESSANDO) 
            && desenho.posicaoFila != null) {
            Text(
                text = "#${desenho.posicaoFila}",
                color = AppColors.TextMuted,
                fontSize = if (isCompact) 10.sp else 12.sp,
                fontFamily = FontFamily.Monospace
            )
        }
        
        // Nome do arquivo
        Text(
            text = desenho.nomeArquivo.ifEmpty { "—" },
            color = AppColors.TextPrimary,
            fontSize = if (isCompact) 12.sp else 14.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
private fun FormatosCell(desenho: DesenhoAutodesk, modifier: Modifier = Modifier, isCompact: Boolean = false) {
    val formatos = desenho.formatosSolicitados
    val status = desenho.statusEnum
    val progresso = desenho.progresso
    
    // Índice do primeiro formato ainda não gerado (o que está sendo processado)
    val primeiroPendenteIdx = remember(formatos, desenho.arquivosProcessados) {
        formatos.indexOfFirst { !desenho.formatoJaGerado(it) }
    }
    
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(if (isCompact) 3.dp else 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (formatos.isEmpty()) {
            Text(
                text = "—",
                color = AppColors.TextMuted,
                fontSize = if (isCompact) 12.sp else 14.sp
            )
        } else {
            formatos.forEachIndexed { idx, formato ->
                val gerado = desenho.formatoJaGerado(formato)
                val emProcessamento = status == DesenhoStatus.PROCESSANDO && !gerado
                val mostrarSpinner = emProcessamento && progresso > 0 && idx == primeiroPendenteIdx
                
                FormatoBadge(
                    formato = formato,
                    gerado = gerado,
                    status = status,
                    emProcessamento = mostrarSpinner,
                    progresso = progresso,
                    isCompact = isCompact
                )
            }
        }
    }
}

@Composable
private fun FormatoBadge(
    formato: String,
    gerado: Boolean,
    status: DesenhoStatus,
    emProcessamento: Boolean = false,
    progresso: Int = 0,
    isCompact: Boolean = false
) {
    val (bgColor, textColor, borderColor) = when {
        gerado -> Triple(AppColors.BadgeGreenBg, AppColors.BadgeGreen, AppColors.BadgeGreen.copy(alpha = 0.5f))
        status == DesenhoStatus.CONCLUIDO_COM_ERROS -> Triple(AppColors.BadgeOrangeBg, AppColors.BadgeOrange, AppColors.BadgeOrange.copy(alpha = 0.5f))
        status == DesenhoStatus.ERRO -> Triple(AppColors.BadgeRedBg, AppColors.BadgeRed, AppColors.BadgeRed.copy(alpha = 0.5f))
        status == DesenhoStatus.CANCELADO -> Triple(AppColors.BadgeOrangeBg, AppColors.BadgeOrange, AppColors.BadgeOrange.copy(alpha = 0.5f))
        emProcessamento -> Triple(AppColors.BadgeBlueBg, AppColors.BadgeBlue, AppColors.BadgeBlue.copy(alpha = 0.5f))
        status == DesenhoStatus.PENDENTE || status == DesenhoStatus.PROCESSANDO -> Triple(AppColors.BadgeYellowBg, AppColors.BadgeYellow, AppColors.BadgeYellow.copy(alpha = 0.5f))
        else -> Triple(AppColors.BadgeGrayBg, AppColors.BadgeGray, AppColors.BadgeGray.copy(alpha = 0.3f))
    }
    
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(if (isCompact) 3.dp else 4.dp))
            .background(bgColor)
            .border(1.dp, borderColor, RoundedCornerShape(if (isCompact) 3.dp else 4.dp))
            .padding(horizontal = if (isCompact) 4.dp else 6.dp, vertical = if (isCompact) 1.dp else 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(if (isCompact) 2.dp else 4.dp)
    ) {
        if (gerado) {
            Icon(
                imageVector = Icons.Filled.Check,
                contentDescription = "Concluído",
                tint = textColor,
                modifier = Modifier.size(if (isCompact) 10.dp else 12.dp)
            )
        }
        if (emProcessamento && !isCompact) {
            CircularProgressIndicator(
                modifier = Modifier.size(12.dp),
                strokeWidth = 1.5.dp,
                color = textColor
            )
            Text(
                text = "${progresso}%",
                color = textColor,
                fontSize = 10.sp,
                fontFamily = FontFamily.Monospace
            )
        }
        Text(
            text = formato.uppercase(),
            color = textColor,
            fontSize = if (isCompact) 9.sp else 11.sp,
            fontFamily = FontFamily.Monospace,
            fontWeight = FontWeight.Medium
        )
    }
}

@Composable
private fun ComputadorCell(computador: String, modifier: Modifier = Modifier) {
    Text(
        text = computador.ifEmpty { "—" },
        color = AppColors.TextPrimary,
        fontSize = 14.sp,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = modifier
    )
}

@Composable
private fun PastaCell(desenho: DesenhoAutodesk, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        val pastaOrigem = desenho.pastaOrigem ?: ""
        val pastaDestino = desenho.caminhoDestino
        
        if (pastaOrigem.isNotEmpty()) {
            ClickablePath(
                label = "Origem",
                path = pastaOrigem
            )
        }
        
        if (pastaDestino.isNotEmpty()) {
            ClickablePath(
                label = "Destino",
                path = pastaDestino
            )
        }
        
        if (pastaOrigem.isEmpty() && pastaDestino.isEmpty()) {
            Text(
                text = "—",
                color = AppColors.TextMuted,
                fontSize = 14.sp
            )
        }
    }
}

@Composable
private fun ClickablePath(
    label: String,
    path: String
) {
    Text(
        text = "$label: ${truncatePath(path)}",
        color = AppColors.Primary,
        fontSize = 12.sp,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        textDecoration = TextDecoration.Underline,
        modifier = Modifier
            .clip(RoundedCornerShape(2.dp))
            .clickable { openInExplorer(path) }
            .pointerHoverIcon(PointerIcon.Hand)
            .padding(vertical = 1.dp)
    )
}

@Composable
private fun EnviadoCell(horarioEnvio: String, modifier: Modifier = Modifier, isCompact: Boolean = false) {
    val horarioFormatado = if (isCompact) {
        // Em modo compacto, mostra apenas hora:minuto
        horarioEnvio
            .replace(Regex("^\\d{4}-\\d{2}-\\d{2}[T ]?"), "")
            .replace(Regex(":\\d{2}\\..*"), "")
            .replace(Regex("\\+\\d{2}$"), "")
    } else {
        horarioEnvio
            .replace(Regex(":\\d{2}\\..*"), "")
            .replace(Regex("\\+\\d{2}$"), "")
    }
    
    Text(
        text = horarioFormatado.ifEmpty { "—" },
        color = AppColors.TextPrimary,
        fontSize = if (isCompact) 12.sp else 13.sp,
        modifier = modifier
    )
}

@Composable
private fun EmptyState() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(48.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = "Nenhum desenho na fila",
                color = AppColors.TextSecondary,
                fontSize = 16.sp
            )
            Text(
                text = "Os desenhos enviados aparecerão aqui",
                color = AppColors.TextMuted,
                fontSize = 14.sp
            )
        }
    }
}

private fun truncatePath(path: String, maxLength: Int = 28): String {
    if (path.length <= maxLength) return path
    return "...${path.takeLast(maxLength - 3)}"
}
