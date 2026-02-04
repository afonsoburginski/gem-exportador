package util

import platform.Foundation.NSDate
import platform.Foundation.NSDateFormatter

actual fun getCurrentDateTime(): String {
    val formatter = NSDateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter.stringFromDate(NSDate())
}
