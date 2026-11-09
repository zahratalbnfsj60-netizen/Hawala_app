package com.transferslog.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable

private val LightColors = lightColorScheme(
    primary = GreenPrimary,
    secondary = GreenLight,
    error = RedPaid,
    background = SurfaceLight
)

private val DarkColors = darkColorScheme(
    primary = GreenLight,
    secondary = GreenPrimary,
    error = RedLight,
    background = DarkBg
)

@Composable
fun TransfersTheme(darkTheme: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content
    )
}
