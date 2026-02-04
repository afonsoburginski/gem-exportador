package util

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

actual fun getCurrentDateTime(): String {
    val sdf = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
    return sdf.format(Date())
}
