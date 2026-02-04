package ui.theme

import androidx.compose.ui.graphics.Color

/**
 * Cores do tema - Simples, sem gradientes
 */
object AppColors {
    // Cores de fundo - Simples e flat
    val Background = Color(0xFF1E1E1E)
    val Surface = Color(0xFF252526)
    val SurfaceVariant = Color(0xFF2D2D30)
    
    // Cores de texto
    val TextPrimary = Color(0xFFD4D4D4)
    val TextSecondary = Color(0xFF9D9D9D)
    val TextMuted = Color(0xFF6D6D6D)
    
    // Cores de status
    val StatusPendente = Color(0xFF6B7280)
    val StatusProcessando = Color(0xFF3B82F6)
    val StatusConcluido = Color(0xFF10B981)
    val StatusErro = Color(0xFFEF4444)
    val StatusCancelado = Color(0xFFF59E0B)
    
    // Cores de borda
    val Border = Color(0xFF3E3E42)
    val BorderLight = Color(0xFF4E4E52)
    
    // Cores de destaque
    val Primary = Color(0xFF0078D4)
    val PrimaryVariant = Color(0xFF005A9E)
    val OnPrimary = Color(0xFFFFFFFF)
    
    // Cores de badges
    val BadgeGreen = Color(0xFF10B981)
    val BadgeGreenBg = Color(0xFF1A3D2E)
    val BadgeBlue = Color(0xFF3B82F6)
    val BadgeBlueBg = Color(0xFF1A2D4D)
    val BadgeRed = Color(0xFFEF4444)
    val BadgeRedBg = Color(0xFF3D1A1A)
    val BadgeGray = Color(0xFF9CA3AF)
    val BadgeGrayBg = Color(0xFF2D2D30)
    val BadgeYellow = Color(0xFFF59E0B)
    val BadgeYellowBg = Color(0xFF3D3A1A)
    // Cancelado = laranja quase vermelho
    val BadgeOrange = Color(0xFFE67E22)
    val BadgeOrangeBg = Color(0xFF3D2A1A)
}
