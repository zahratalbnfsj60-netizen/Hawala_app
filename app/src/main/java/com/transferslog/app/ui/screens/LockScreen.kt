package com.transferslog.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.fragment.app.FragmentActivity
import com.transferslog.app.ui.theme.GreenBright
import com.transferslog.app.util.AppPrefs
import com.transferslog.app.util.BiometricHelper

@Composable
fun LockScreen(activity: FragmentActivity, onSuccess: () -> Unit) {
    val ctx = LocalContext.current
    LaunchedEffect(Unit) { AppPrefs.init(ctx) }
    LaunchedEffect(Unit) { BiometricHelper.authenticate(activity, onSuccess) { } }

    Box(Modifier.fillMaxSize().background(Color.Black), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Default.Lock, null, tint = GreenBright, modifier = Modifier.size(80.dp))
            Spacer(Modifier.height(16.dp))
            Text("التطبيق مقفل", color = Color.White, fontSize = 22.sp)
            Spacer(Modifier.height(24.dp))
            Button(onClick = { BiometricHelper.authenticate(activity, onSuccess) { } }, colors = ButtonDefaults.buttonColors(containerColor = GreenBright)) {
                Text("مصادقة", color = Color.Black)
            }
        }
    }
}
