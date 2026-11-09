package com.transferslog.app.ui.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.transferslog.app.ui.theme.*
import com.transferslog.app.ui.viewmodel.SettingsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(vm: SettingsViewModel, onBack: () -> Unit) {
    val context = LocalContext.current
    val currency by vm.currency.collectAsState(initial = "ل.س")
    val c1 by vm.commission1.collectAsState(initial = 100.0)
    val c2 by vm.commission2.collectAsState(initial = 250.0)
    val uiState by vm.uiState.collectAsState()
    val snackbar = remember { SnackbarHostState() }

    var showDeleteConfirm1 by remember { mutableStateOf(false) }
    var showDeleteConfirm2 by remember { mutableStateOf(false) }

    LaunchedEffect(uiState.message) {
        uiState.message?.let { snackbar.showSnackbar(it); vm.clearMessage() }
    }

    val exportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        uri?.let {
            vm.exportData { json ->
                if (json != null) {
                    context.contentResolver.openOutputStream(it)?.use { os -> os.write(json.toByteArray()) }
                }
            }
        }
    }

    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri?.let {
            context.contentResolver.openInputStream(it)?.use { isr ->
                val json = isr.readBytes().decodeToString()
                vm.importData(json) { _ -> }
            }
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = { 
            TopAppBar(
                title = { Text("الإعدادات") }, 
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, null) } }, 
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Black, titleContentColor = White, navigationIconContentColor = White)
            ) 
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize().background(Black)) {
            if (uiState.isLoading) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center), color = GreenAccent)
            }
            Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                OutlinedTextField(value = currency, onValueChange = { vm.setCurrency(it) }, label = { Text("العملة") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))
                OutlinedTextField(value = c1.toString(), onValueChange = { it.toDoubleOrNull()?.let { v -> vm.setComm1(v) } }, label = { Text("العمولة الأولى") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))
                OutlinedTextField(value = c2.toString(), onValueChange = { it.toDoubleOrNull()?.let { v -> vm.setComm2(v) } }, label = { Text("العمولة الثانية") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))

                Divider(color = LightGray, modifier = Modifier.padding(vertical = 8.dp))

                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { exportLauncher.launch("hawala_backup.json") }, modifier = Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = DarkGray)) { Text("تصدير JSON", color = White) }
                    Button(onClick = { importLauncher.launch(arrayOf("application/json")) }, modifier = Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = DarkGray)) { Text("استيراد JSON", color = White) }
                }

                Button(onClick = { showDeleteConfirm1 = true }, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = RedAccent)) {
                    Text("حذف كل البيانات")
                }

                Divider(color = LightGray, modifier = Modifier.padding(vertical = 8.dp))
                Text("عن البرنامج", color = White, style = MaterialTheme.typography.titleLarge)
                Text("الإصدار: 1.0", color = SecondaryText)
                Text("المبرمج: أدهم الهبة", color = SecondaryText)
            }
        }
    }

    if (showDeleteConfirm1) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm1 = false },
            title = { Text("تحذير خطير!") },
            text = { Text("سيتم حذف جميع الحسابات والحوالات نهائياً. هل تريد المتابعة؟") },
            confirmButton = { TextButton(onClick = { showDeleteConfirm1 = false; showDeleteConfirm2 = true }) { Text("نعم", color = RedAccent) } },
            dismissButton = { TextButton(onClick = { showDeleteConfirm1 = false }) { Text("إلغاء") } }
        )
    }

    if (showDeleteConfirm2) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm2 = false },
            title = { Text("تأكيد أخير") },
            text = { Text("هل أنت متأكد 100%؟ لا يمكن التراجع عن هذه الخطوة!") },
            confirmButton = { TextButton(onClick = { vm.deleteAll { showDeleteConfirm2 = false } }) { Text("نعم، احذف نهائياً", color = RedAccent) } },
            dismissButton = { TextButton(onClick = { showDeleteConfirm2 = false }) { Text("إلغاء") } }
        )
    }
}
