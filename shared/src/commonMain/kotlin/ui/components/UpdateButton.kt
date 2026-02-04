package ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ui.theme.AppColors

/**
 * Botão de atualização disponível para a toolbar
 * Aparece quando há uma atualização disponível e o usuário fechou o dialog
 */
@Composable
fun UpdateButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(5.dp))
            .border(1.dp, AppColors.Primary.copy(alpha = 0.5f), RoundedCornerShape(5.dp))
            .background(AppColors.Primary.copy(alpha = 0.1f))
            .clickable { onClick() }
            .pointerHoverIcon(PointerIcon.Hand)
            .padding(horizontal = 10.dp, vertical = 6.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Badge indicador
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(AppColors.Primary)
            )
            
            // Ícone de update
            Text(
                text = "⬆",
                fontSize = 12.sp,
                color = AppColors.Primary
            )
            
            Text(
                text = "Atualizar",
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.Primary
            )
        }
    }
}
