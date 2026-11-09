package com.transferslog.app.ui.theme

import androidx.compose.material3.*
import androidx.compose.runtime.Composable

private val BlackColors = darkColorScheme(
    primary = GreenReceived,
    onPrimary = WhiteText,
    secondary = GreenBright,
    onSecondary = WhiteText,
    tertiary = GoldProfit,
    onTertiary = BlackBg,
    error = RedPaid,
    onError = WhiteText,
    background = BlackBg,
    onBackground = WhiteText,
    surface = DarkSurface,
    onSurface = WhiteText,
    surfaceVariant = DarkCard,
    onSurfaceVariant = GrayText,
    outline = DividerGray
)

@Composable
fun TransfersTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = BlackColors, content = content)
}
