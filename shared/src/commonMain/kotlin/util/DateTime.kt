package util

/**
 * Retorna a data/hora atual como string
 * Implementação específica por plataforma
 */
expect fun getCurrentDateTime(): String

/**
 * Retorna a data de hoje no formato yyyy-MM-dd
 */
expect fun getTodayDate(): String

/**
 * Retorna a data de N dias atrás no formato yyyy-MM-dd
 */
expect fun getDaysAgoDate(days: Int): String
