package com.transferslog.app.ui.theme
import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.transferslog.app.R

val CairoFamily = FontFamily(
    Font(R.font.cairo_regular, FontWeight.Normal),
    Font(R.font.cairo_medium, FontWeight.Medium),
    Font(R.font.cairo_semibold, FontWeight.SemiBold),
    Font(R.font.cairo_bold, FontWeight.Bold),
)
val AppTypography = Typography(
    displayLarge = TextStyle(fontFamily = CairoFamily, fontWeight = FontWeight.Bold, fontSize = 32.sp),
    headlineMedium = TextStyle(fontFamily = CairoFamily, fontWeight = FontWeight.Bold, fontSize = 22.sp),
    titleLarge = TextStyle(fontFamily = CairoFamily, fontWeight = FontWeight.Bold, fontSize = 18.sp),
    titleMedium = TextStyle(fontFamily = CairoFamily, fontWeight = FontWeight.SemiBold, fontSize = 16.sp),
    bodyLarge = TextStyle(fontFamily = CairoFamily, fontWeight = FontWeight.Normal, fontSize = 16.sp),
    bodyMedium = TextStyle(fontFamily = CairoFamily, fontWeight = FontWeight.Normal, fontSize = 14.sp),
    labelLarge = TextStyle(fontFamily = CairoFamily, fontWeight = FontWeight.SemiBold, fontSize = 14.sp),
    labelSmall = TextStyle(fontFamily = CairoFamily, fontWeight = FontWeight.Normal, fontSize = 12.sp),
)
