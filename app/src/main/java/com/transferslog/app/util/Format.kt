package com.transferslog.app.util
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.*
private val nf = NumberFormat.getNumberInstance(Locale.US).apply { maximumFractionDigits = 2; minimumFractionDigits = 0 }
private val df = SimpleDateFormat("yyyy/MM/dd", Locale("ar"))
fun formatNum(v: Double): String = nf.format(v)
fun formatDate(ms: Long): String = df.format(Date(ms))
fun toStartOfDay(ms: Long): Long {
    val c = Calendar.getInstance().apply { timeInMillis = ms; set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }
    return c.timeInMillis
}
fun toEndOfDay(ms: Long): Long = toStartOfDay(ms) + 86_400_000L - 1
