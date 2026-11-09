package com.transferslog.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.sp

val Black = Color(0xFF000000)
val DarkGray = Color(0xFF161616)
val LightGray = Color(0xFF1F1F1F)
val White = Color(0xFFFFFFFF)
val SecondaryText = Color(0xFF9E9E9E)
val GreenAccent = Color(0xFF00C853)
val RedAccent = Color(0xFFE53935)

private val DarkColorScheme = darkColorScheme(
    primary = GreenAccent, secondary = RedAccent, background = Black, surface = DarkGray,
    onPrimary = Black, onSecondary = White, onBackground = White, onSurface = White
)

val AppTypography = Typography(bodyLarge = TextStyle(fontFamily = FontFamily.Default, fontSize = 16.sp))

@Composable
fun TransfersLogTheme(darkTheme: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = DarkColorScheme, typography = AppTypography, content = content)
}
