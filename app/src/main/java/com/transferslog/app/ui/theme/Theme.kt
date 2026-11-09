package com.transferslog.app.ui.theme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
private val DarkScheme = darkColorScheme(
    primary = GreenBright, onPrimary = Black, secondary = RedBright, onSecondary = White,
    background = Black, onBackground = White, surface = CardDark, onSurface = White,
    surfaceVariant = CardDark2, onSurfaceVariant = GrayText, outline = CardDark2, error = RedBright
)
@Composable
fun HawalaTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = DarkScheme, typography = AppTypography, content = content)
}
