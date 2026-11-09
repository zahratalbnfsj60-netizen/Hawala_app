package com.transferslog.app.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.transferslog.app.data.*
import com.transferslog.app.viewmodel.MainViewModel
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEditTransferScreen(
    vm: MainViewModel,
    type: String,
    editId: Int,
    onBack: () -> Unit
) {
    val accounts by vm.accounts.collectAsState()
    val savedNames by vm.savedNames.collectAsState()
    val transfers by vm.transfers.collectAsState()
    val isPaid = type == "PAID"
    val existing = transfers.firstOrNull { it.id == editId }

    var name by remember { mutableStateOf(existing?.recipientName ?: "") }
    var amount by remember { mutableStateOf(existing?.amount?.toString() ?: "") }
    var commission by remember { mutableStateOf(existing?.commission ?: if (isPaid) 100.0 else 0.0) }
    var selectedAccount by remember { mutableStateOf(existing?.accountId ?: accounts.firstOrNull()?.id) }
    var note by remember { mutableStateOf(existing?.note ?: "") }
    var date by remember { mutableStateOf(existing?.date ?: System.currentTimeMillis()) }
    var showSuggestions by remember { mutableStateOf(false) }
    var showDatePicker by remember { mutableStateOf(false) }
    var showDeleteDialog by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        if (selectedAccount == null) selectedAccount = accounts.firstOrNull()?.id
    }

    if (showDatePicker) {
        val state = rememberDatePickerState(initialSelectedDateMillis = date)
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let { date = it }
                    showDatePicker = false
                }) { Text("موافق") }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text("إلغاء") }
            }
        ) { DatePicker(state = state) }
    }

    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text("حذف الحوالة") },
            text = { Text("هل أنت متأكد من حذف هذه الحوالة؟") },
            confirmButton = {
                TextButton(onClick = {
                    existing?.let { vm.deleteTransfer(it) }
                    showDeleteDialog = false
                    onBack()
                }) { Text("حذف", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) { Text("إلغاء") }
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (editId == 0) "إضافة حوالة" else "تعديل حوالة") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, "رجوع") }
                },
                actions = {
                    if (editId != 0) {
                        TextButton(onClick = { showDeleteDialog = true }) {
                            Text("حذف", color = Color.White)
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = if (isPaid) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary,
                    titleContentColor = Color.White,
                    navigationIconContentColor = Color.White
                )
            )
        }
    ) { padding ->
        Column(
            Modifier.padding(padding).padding(16.dp).fillMaxSize().verticalScroll(rememberScrollState())
        ) {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it; showSuggestions = true },
                label = { Text("اسم المستلم") },
                modifier = Modifier.fillMaxWidth()
            )
            if (showSuggestions && name.isNotBlank()) {
                val sugg = savedNames.filter { it.name.contains(name, true) && it.name != name }.take(3)
                sugg.forEach { sn ->
                    Text(
                        sn.name,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { name = sn.name; showSuggestions = false }
                            .padding(horizontal = 16.dp, vertical = 8.dp)
                    )
                }
            }
            Spacer(Modifier.height(8.dp))

            OutlinedTextField(
                value = amount,
                onValueChange = { amount = it.filter { c -> c.isDigit() || c == '.' } },
                label = { Text("المبلغ (ل.س)") },
                modifier = Modifier.fillMaxWidth()
            )

            if (isPaid) {
                Spacer(Modifier.height(12.dp))
                Text("العمولة", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Row {
                    RadioButton(selected = commission == 100.0, onClick = { commission = 100.0 })
                    Text("100 ل.س", modifier = Modifier.padding(top = 12.dp))
                    Spacer(Modifier.width(16.dp))
                    RadioButton(selected = commission == 250.0, onClick = { commission = 250.0 })
                    Text("250 ل.س", modifier = Modifier.padding(top = 12.dp))
                }
            }

            Spacer(Modifier.height(12.dp))
            OutlinedButton(
                onClick = { showDatePicker = true },
                modifier = Modifier.fillMaxWidth()
            ) {
                Icon(Icons.Default.DateRange, null)
                Spacer(Modifier.width(8.dp))
                Text(SimpleDateFormat("yyyy/MM/dd", Locale.getDefault()).format(Date(date)))
            }

            Spacer(Modifier.height(12.dp))
            var expanded by remember { mutableStateOf(false) }
            ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
                OutlinedTextField(
                    value = accounts.firstOrNull { it.id == selectedAccount }?.name ?: "اختر الحساب",
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("الحساب") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
                    modifier = Modifier.menuAnchor().fillMaxWidth()
                )
                ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                    accounts.forEach { acc ->
                        DropdownMenuItem(
                            text = { Text(acc.name) },
                            onClick = { selectedAccount = acc.id; expanded = false }
                        )
                    }
                }
            }

            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = note,
                onValueChange = { note = it },
                label = { Text("ملاحظة (اختياري)") },
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.height(20.dp))
            Button(
                onClick = {
                    val accId = selectedAccount ?: return@Button
                    val t = Transfer(
                        id = editId,
                        type = if (isPaid) TransferType.PAID else TransferType.RECEIVED,
                        recipientName = name.trim(),
                        amount = amount.toDoubleOrNull() ?: 0.0,
                        commission = if (isPaid) commission else 0.0,
                        date = date,
                        accountId = accId,
                        note = note.ifBlank { null },
                        paidNumber = existing?.paidNumber
                    )
                    vm.saveTransfer(t) { onBack() }
                },
                enabled = name.isNotBlank() && amount.toDoubleOrNull() != null && selectedAccount != null,
                modifier = Modifier.fillMaxWidth()
            ) { Text("حفظ") }
        }
    }
}
