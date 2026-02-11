package util

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

actual fun getCurrentDateTime(): String {
    return LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"))
}

actual fun getTodayDate(): String {
    return LocalDate.now().toString() // yyyy-MM-dd
}

actual fun getDaysAgoDate(days: Int): String {
    return LocalDate.now().minusDays(days.toLong()).toString() // yyyy-MM-dd
}
