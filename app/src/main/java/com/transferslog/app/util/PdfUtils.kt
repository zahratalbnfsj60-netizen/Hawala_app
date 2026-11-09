package com.transferslog.app.util

import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.net.Uri
import androidx.core.content.FileProvider
import com.transferslog.app.data.Transfer
import com.transferslog.app.data.TransferType
import java.io.File
import java.io.FileOutputStream
import java.text.DecimalFormat
import java.text.SimpleDateFormat
import java.util.*

object PdfUtils {
    fun generateAndShare(context: Context, transfers: List<Transfer>, accountName: String, startDate: Long, endDate: Long) {
        val document = PdfDocument()
        val paint = Paint()
        val titlePaint = Paint().apply { textSize = 20f; isFakeBoldText = true }
        val pageInfo = PdfDocument.PageInfo.Builder(595, 842, 1).create()
        val page = document.startPage(pageInfo)
        val canvas = page.canvas

        var y = 50f
        paint.textSize = 14f
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val numFormat = DecimalFormat("#,###.##")

        canvas.drawText("كشف حساب: $accountName", 50f, y, titlePaint)
        y += 30f
        canvas.drawText("من: ${dateFormat.format(Date(startDate))} إلى: ${dateFormat.format(Date(endDate))}", 50f, y, paint)
        y += 40f

        canvas.drawText("التاريخ", 50f, y, titlePaint)
        canvas.drawText("الاسم", 150f, y, titlePaint)
        canvas.drawText("المبلغ", 350f, y, titlePaint)
        canvas.drawText("النوع", 450f, y, titlePaint)
        y += 20f
        canvas.drawLine(50f, y, 550f, y, paint)
        y += 20f

        var totalPaid = 0.0
        var totalReceived = 0.0

        for (t in transfers) {
            canvas.drawText(dateFormat.format(Date(t.date)), 50f, y, paint)
            canvas.drawText(t.recipientName, 150f, y, paint)
            canvas.drawText(numFormat.format(t.amount), 350f, y, paint)
            canvas.drawText(if (t.type == TransferType.PAID) "مدفوع" else "مستلم", 450f, y, paint)
            if (t.type == TransferType.PAID) totalPaid += t.amount else totalReceived += t.amount
            y += 20f
            if (y > 800) {
                document.finishPage(page)
                val newPage = document.startPage(PdfDocument.PageInfo.Builder(595, 842, 2).create())
                y = 50f
            }
        }

        y += 20f
        canvas.drawText("إجمالي المدفوع: ${numFormat.format(totalPaid)}", 50f, y, titlePaint)
        y += 20f
        canvas.drawText("إجمالي المستلم: ${numFormat.format(totalReceived)}", 50f, y, titlePaint)
        document.finishPage(page)

        val file = File(context.cacheDir, "statement.pdf")
        try {
            document.writeTo(FileOutputStream(file))
            document.close()
            val uri: Uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
            val intent = Intent(Intent.ACTION_SEND).apply { type = "application/pdf"; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION) }
            context.startActivity(Intent.createChooser(intent, "مشاركة كشف الحساب"))
        } catch (e: Exception) { e.printStackTrace() }
    }
}
