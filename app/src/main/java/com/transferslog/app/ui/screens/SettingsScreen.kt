package com.transferslog.app.ui.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.transferslog.app.ui.theme.*
import com.transferslog.app.ui.viewmodel.SettingsViewModel
import com.transferslog.app.util.PdfUtils
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(vm: SettingsViewModel, onBack: () -> Unit) {
    val context = LocalContext.current
    val currency by vm.currency.collectAsState(initial = "ل.س")
    val c1 by vm.commission1.collectAsState(initial = 100.0)
    val c2 by vm.commission2.collectAsState(initial = 250.0)
    val uiState by vm.uiState.collectAsState()
    val snackbar = remember { SnackbarHostState() }
    var showDateRangeForPdf by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(uiState.message) { uiState.message?.let { snackbar.showSnackbar(it); vm.clearMessage() } }

    val exportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        uri?.let { vm.exportData { json -> if (json != null) context.contentResolver.openOutputStream(it)?.use { os -> os.write(json.toByteArray()) } } }
    }
    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri?.let { context.contentResolver.openInputStream(it)?.use { isr -> vm.importData(isr.readBytes().decodeToString()) { _ -> } } }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = { TopAppBar(title = { Text("الإعدادات") }, navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, null) } }, colors = TopAppBarDefaults.topAppBarColors(containerColor = Black, titleContentColor = White, navigationIconContentColor = White)) }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize().background(Black)) {
            if (uiState.isLoading) CircularProgressIndicator(modifier = Modifier.align(Alignment.Center), color = GreenAccent)
            Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                OutlinedTextField(value = currency, onValueChange = { vm.setCurrency(it) }, label = { Text("العملة") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))
                OutlinedTextField(value = c1.toString(), onValueChange = { it.toDoubleOrNull()?.let { v -> vm.setComm1(v) } }, label = { Text("العمولة الأولى") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))
                OutlinedTextField(value = c2.toString(), onValueChange = { it.toDoubleOrNull()?.let { v -> vm.setComm2(v) } }, label = { Text("العمولة الثانية") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))

                Divider(color = LightGray, modifier = Modifier.padding(vertical = 8.dp))
                Text("النسخ الاحتياطي", color = White, style = MaterialTheme.typography.titleMedium)
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { exportLauncher.launch("hawala_backup.json") }, modifier = Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = DarkGray)) { Text("تصدير JSON", color = White) }
                    Button(onClick = { importLauncher.launch(arrayOf("application/json")) }, modifier = Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = DarkGray)) { Text("استيراد JSON", color = White) }
                }

                Divider(color = LightGray, modifier = Modifier.padding(vertical = 8.dp))
                Text("تصدير PDF", color = White, style = MaterialTheme.typography.titleMedium)
                Button(onClick = { showDateRangeForPdf = true }, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = GreenAccent)) { Text("تصدير ومشاركة كشف حساب", color = Black) }

                Button(onClick = { vm.deleteAll { } }, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = RedAccent)) { Text("حذف كل البيانات") }

                Divider(color = LightGray, modifier = Modifier.padding(vertical = 8.dp))
                Text("عن البرنامج", color = White, style = MaterialTheme.typography.titleLarge)
                Text("الإصدار: 2.0", color = SecondaryText)
                Text("المبرمج: أدهم الهبة", color = SecondaryText)
            }
        }
    }

    if (showDateRangeForPdf) {
        val dateState = rememberDateRangePickerState()
        DatePickerDialog(
            onDismissRequest = { showDateRangeForPdf = false },
            confirmButton = {
                TextButton(onClick = {
                    showDateRangeForPdf = false
                    val start = dateState.selectedStartDateMillis ?: 0L
                    val end = dateState.selectedEndDateMillis ?: System.currentTimeMillis()
                    scope.launch {
                        val accountId = vm.repo.accountDao.getAll().first().firstOrNull()?.id
                        if (accountId != null) {
                            val accName = vm.repo.accountDao.getById(accountId)?.name ?: ""
                            val list = vm.repo.transferDao.getFiltered(accountId, null, "", start, end).first()
                            if (list.isNotEmpty()) PdfUtils.generateAndShare(context, list, accName, start, end)
                        }
                    }
                }) { Text("تصدير") }
            },
            dismissButton = { TextButton(onClick = { showDateRangeForPdf = false }) { Text("إلغاء") } }
        ) { DateRangePicker(state = dateState) }
    }
}
