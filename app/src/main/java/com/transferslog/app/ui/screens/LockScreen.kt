package com.transferslog.app.ui.screens

import androidx.activity.ComponentActivity
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.transferslog.app.ui.theme.Black
import com.transferslog.app.ui.theme.GreenAccent
import com.transferslog.app.ui.theme.White

@Composable
fun LockScreen(onUnlock: () -> Unit) {
    val context = LocalContext.current
    val activity = context as ComponentActivity

    val executor = ContextCompat.getMainExecutor(context)
    val biometricPrompt = BiometricPrompt(activity, executor, object : BiometricPrompt.AuthenticationCallback() {
        override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
            super.onAuthenticationSucceeded(result)
            onUnlock()
        }
    })

    val promptInfo = BiometricPrompt.PromptInfo.Builder()
        .setTitle("قفل التطبيق")
        .setSubtitle("الرجاء المصادقة للدخول")
        .setNegativeButtonText("إلغاء")
        .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.DEVICE_CREDENTIAL)
        .build()

    Box(modifier = Modifier.fillMaxSize().background(Black), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Default.Lock, contentDescription = null, tint = GreenAccent, modifier = Modifier.size(80.dp))
            Spacer(Modifier.height(24.dp))
            Text("التطبيق مقفل", color = White, fontSize = 24.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(32.dp))
            Button(
                onClick = { biometricPrompt.authenticate(promptInfo) },
                colors = ButtonDefaults.buttonColors(containerColor = GreenAccent)
            ) {
                Text("فتح القفل", color = Black, fontSize = 18.sp)
            }
        }
    }
}
