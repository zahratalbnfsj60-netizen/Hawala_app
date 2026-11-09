package com.transferslog.app.util

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.text.TextUtils
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import com.transferslog.app.data.Account
import com.transferslog.app.data.Transfer
import com.transferslog.app.data.TransferType
import java.io.File
import java.io.FileOutputStream

object PdfExporter {
    private const val PW = 595
    private const val PH = 842
    private const val M = 24f

    fun export(ctx: Context, account: Account, transfers: List<Transfer>, fromMs: Long, toMs: Long, currency: String): File {
        val doc = PdfDocument()
        var pageNum = 1
        var page: PdfDocument.Page? = null
        var canvas: Canvas? = null
        var y = M

        fun newPage() {
            page?.let { doc.finishPage(it) }
            val info = PdfDocument.PageInfo.Builder(PW, PH, pageNum++).create()
            page = doc.startPage(info)
            canvas = page!!.canvas
            y = M
        }

        fun draw(ctx: Context, text: String, size: Float = 12f, color: Int = Color.BLACK, bold: Boolean = false) {
            val tv = TextView(ctx).apply {
                this.text = text; textSize = size; setTextColor(color); textDirection = View.TEXT_DIRECTION_RTL; gravity = Gravity.RIGHT
                if (bold) typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                layoutParams = ViewGroup.LayoutParams((PW - 2 * M).toInt(), ViewGroup.LayoutParams.WRAP_CONTENT)
                maxLines = 4; ellipsize = TextUtils.TruncateAt.END
            }
            val w = View.MeasureSpec.makeMeasureSpec((PW - 2 * M).toInt(), View.MeasureSpec.EXACTLY)
            val h = View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
            tv.measure(w, h); tv.layout(0, 0, tv.measuredWidth, tv.measuredHeight)
            if (y + tv.measuredHeight + M > PH) newPage()
            canvas!!.save(); canvas!!.translate(M, y); tv.draw(canvas!!); canvas!!.restore()
            y += tv.measuredHeight + 4f
        }

        newPage()
        draw(ctx, "كشف حساب - ${account.name}", 18f, bold = true)
        draw(ctx, "الفترة: ${formatDate(fromMs)} — ${formatDate(toMs)}", 12f)
        draw(ctx, "العملة: $currency", 12f)
        draw(ctx, "────────────────────────────────────", 10f)

        var received = 0.0; var paid = 0.0; var comm = 0.0
        transfers.forEach { t ->
            if (t.type == TransferType.PAID) {
                paid += t.amount; comm += t.commission
                draw(ctx, "مدفوع #${t.paidNumber} | ${t.recipientName}", 12f, Color.rgb(229, 57, 53), true)
                draw(ctx, "  المبلغ: ${formatNum(t.amount)}  |  العمولة: ${formatNum(t.commission)}  |  ${formatDate(t.date)}", 11f)
            } else {
                received += t.amount
                draw(ctx, "مستلم | ${t.recipientName}", 12f, Color.rgb(0, 200, 83), true)
                draw(ctx, "  المبلغ: ${formatNum(t.amount)}  |  ${formatDate(t.date)}", 11f)
            }
        }

        y += 12f
        draw(ctx, "────────────────────────────────────", 10f)
        draw(ctx, "الرصيد الافتتاحي: ${formatNum(account.openingBalance)}", 12f, bold = true)
        draw(ctx, "إجمالي المستلم: ${formatNum(received)}", 12f, Color.rgb(0, 200, 83), true)
        draw(ctx, "إجمالي المدفوع: ${formatNum(paid)}", 12f, Color.rgb(229, 57, 53), true)
        draw(ctx, "إجمالي العمولات: ${formatNum(comm)}", 12f, bold = true)
        draw(ctx, "الرصيد الحالي: ${formatNum(account.openingBalance + received - paid - comm)}", 16f, bold = true)

        page?.let { doc.finishPage(it) }
        val file = File(ctx.cacheDir, "statement_${System.currentTimeMillis()}.pdf")
        FileOutputStream(file).use { doc.writeTo(it) }
        doc.close()
        return file
    }
}
