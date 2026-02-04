package ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import ui.theme.AppColors
import util.AppVersion
import util.VersionInfo

/**
 * Estado da atualização
 */
sealed class UpdateState {
    object Idle : UpdateState()
    object WaitingQueue : UpdateState()
    data class Downloading(val progress: Int) : UpdateState()
    object Installing : UpdateState()
    data class Error(val message: String) : UpdateState()
}

/**
 * Dialog de atualização disponível
 */
@Composable
fun UpdateDialog(
    versionInfo: VersionInfo,
    updateState: UpdateState,
    queueEmpty: Boolean,
    onUpdate: () -> Unit,
    onDismiss: () -> Unit
) {
    Dialog(onDismissRequest = { if (updateState == UpdateState.Idle) onDismiss() }) {
        Box(
            modifier = Modifier
                .width(420.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(AppColors.Surface)
                .border(1.dp, AppColors.Border, RoundedCornerShape(12.dp))
                .padding(24.dp)
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Ícone de atualização
                Text(
                    text = "⬆",
                    fontSize = 48.sp,
                    color = AppColors.Primary
                )
                
                // Título
                Text(
                    text = "Atualização Disponível",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.TextPrimary
                )
                
                // Versões
                Row(
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    VersionBadge(
                        label = "Atual",
                        version = AppVersion.current,
                        isOld = true
                    )
                    Text(
                        text = "→",
                        fontSize = 20.sp,
                        color = AppColors.TextSecondary
                    )
                    VersionBadge(
                        label = "Nova",
                        version = versionInfo.version,
                        isOld = false
                    )
                }
                
                // Release notes
                if (versionInfo.releaseNotes.isNotBlank()) {
                    Text(
                        text = versionInfo.releaseNotes.take(200),
                        fontSize = 13.sp,
                        color = AppColors.TextSecondary,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 8.dp)
                    )
                }
                
                // Estado da atualização
                when (updateState) {
                    is UpdateState.WaitingQueue -> {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(16.dp),
                                strokeWidth = 2.dp,
                                color = AppColors.BadgeYellow
                            )
                            Text(
                                text = "Aguardando processos terminarem...",
                                fontSize = 13.sp,
                                color = AppColors.BadgeYellow
                            )
                        }
                    }
                    is UpdateState.Downloading -> {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            LinearProgressIndicator(
                                progress = updateState.progress / 100f,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(8.dp)
                                    .clip(RoundedCornerShape(4.dp)),
                                color = AppColors.Primary,
                                backgroundColor = AppColors.SurfaceVariant
                            )
                            Text(
                                text = "Baixando... ${updateState.progress}%",
                                fontSize = 13.sp,
                                color = AppColors.TextSecondary
                            )
                        }
                    }
                    is UpdateState.Installing -> {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(16.dp),
                                strokeWidth = 2.dp,
                                color = AppColors.Primary
                            )
                            Text(
                                text = "Iniciando instalador...",
                                fontSize = 13.sp,
                                color = AppColors.Primary
                            )
                        }
                    }
                    is UpdateState.Error -> {
                        Text(
                            text = "Erro: ${updateState.message}",
                            fontSize = 13.sp,
                            color = AppColors.BadgeRed
                        )
                    }
                    else -> {}
                }
                
                Spacer(modifier = Modifier.height(8.dp))
                
                // Botões
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    // Botão "Depois"
                    OutlinedButton(
                        onClick = onDismiss,
                        enabled = updateState == UpdateState.Idle || updateState is UpdateState.Error,
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = AppColors.TextSecondary
                        )
                    ) {
                        Text("Depois")
                    }
                    
                    // Botão "Atualizar"
                    Button(
                        onClick = onUpdate,
                        enabled = updateState == UpdateState.Idle || updateState is UpdateState.Error,
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(
                            backgroundColor = AppColors.Primary,
                            contentColor = AppColors.OnPrimary
                        )
                    ) {
                        Text(
                            if (queueEmpty) "Atualizar Agora" else "Atualizar"
                        )
                    }
                }
                
                // Aviso se há processos na fila
                if (!queueEmpty && updateState == UpdateState.Idle) {
                    Text(
                        text = "A atualização será iniciada após os processos em andamento.",
                        fontSize = 11.sp,
                        color = AppColors.TextMuted,
                        textAlign = TextAlign.Center
                    )
                }
            }
        }
    }
}

@Composable
private fun VersionBadge(
    label: String,
    version: String,
    isOld: Boolean
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = label,
            fontSize = 11.sp,
            color = AppColors.TextMuted
        )
        Text(
            text = "v$version",
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium,
            color = if (isOld) AppColors.TextSecondary else AppColors.Primary
        )
    }
}
