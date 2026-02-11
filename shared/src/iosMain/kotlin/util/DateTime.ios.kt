package util

import platform.Foundation.NSCalendar
import platform.Foundation.NSDate
import platform.Foundation.NSDateFormatter

actual fun getCurrentDateTime(): String {
    val formatter = NSDateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter.stringFromDate(NSDate())
}

actual fun getTodayDate(): String {
    val formatter = NSDateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.stringFromDate(NSDate())
}

actual fun getDaysAgoDate(days: Int): String {
    val formatter = NSDateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    val calendar = NSCalendar.currentCalendar
    val pastDate = calendar.dateByAddingUnit(
        unit = platform.Foundation.NSCalendarUnitDay,
        value = -days.toLong(),
        toDate = NSDate(),
        options = 0u
    )
    return formatter.stringFromDate(pastDate ?: NSDate())
}
