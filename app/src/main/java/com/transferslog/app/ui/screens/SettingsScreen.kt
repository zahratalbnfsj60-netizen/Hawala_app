package com.transferslog.app.ui.screens

import android.content.Context
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import com.transferslog.app.viewmodel.MainViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(vm: MainViewModel, nav: NavController) {
    val ctx = LocalContext.current
    val prefs = remember { ctx.getSharedPreferences("settings", Context.MODE_PRIVATE) }
    var currency by remember { mutableStateOf(prefs.getString("currency", "ل.س") ?: "ل.س") }
    var commission1 by remember { mutableStateOf(prefs.getString("commission1", "100") ?: "100") }
    var commission2 by remember { mutableStateOf(prefs.getString("commission2", "250") ?: "250") }
    var showClearDialog by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("الإعدادات") },
                navigationIcon = {
                    IconButton(onClick = { nav.popBackStack() }) {
                        Icon(Icons.Default.ArrowBack, "رجوع", tint = Color.White)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = Color.White
                )
            )
        }
    ) { padding ->
        Column(Modifier.padding(padding).padding(16.dp).fillMaxSize().verticalScroll(rememberScrollState())) {
            Text("العملة", style = MaterialTheme.typography.titleMedium)
            OutlinedTextField(
                value = currency,
                onValueChange = { currency = it; prefs.edit().putString("currency", it).apply() },
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height(16.dp))

            Text("قيم العمولة", style = MaterialTheme.typography.titleMedium)
            Row {
                OutlinedTextField(
                    value = commission1,
                    onValueChange = { commission1 = it; prefs.edit().putString("commission1", it).apply() },
                    label = { Text("العمولة 1") },
                    modifier = Modifier.weight(1f)
                )
                Spacer(Modifier.width(8.dp))
                OutlinedTextField(
                    value = commission2,
                    onValueChange = { commission2 = it; prefs.edit().putString("commission2", it).apply() },
                    label = { Text("العمولة 2") },
                    modifier = Modifier.weight(1f)
                )
            }
            Spacer(Modifier.height(24.dp))

            Button(
                onClick = { showClearDialog = true },
                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
                modifier = Modifier.fillMaxWidth()
            ) { Text("حذف كل البيانات") }

            Spacer(Modifier.height(24.dp))
            Text("رقم الإصدار 1.0", style = MaterialTheme.typography.bodySmall)
        }
    }

    if (showClearDialog) {
        AlertDialog(
            onDismissRequest = { showClearDialog = false },
            title = { Text("حذف كل البيانات") },
            text = { Text("سيتم حذف جميع الحوالات والحسابات والأسماء المحفوظة نهائياً. هل أنت متأكد؟") },
            confirmButton = {
                TextButton(onClick = {
                    vm.clearAll()
                    showClearDialog = false
                }) { Text("حذف الكل", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showClearDialog = false }) { Text("إلغاء") }
            }
        )
    }
}
