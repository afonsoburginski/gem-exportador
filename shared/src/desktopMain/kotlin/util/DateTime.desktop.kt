package util

import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

actual fun getCurrentDateTime(): String {
    return LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"))
}
