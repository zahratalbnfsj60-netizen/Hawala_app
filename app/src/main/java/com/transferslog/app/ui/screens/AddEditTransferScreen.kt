package com.transferslog.app.ui.screens

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
import androidx.compose.ui.unit.dp
import com.transferslog.app.data.TransferType
import com.transferslog.app.ui.theme.*
import com.transferslog.app.ui.viewmodel.AddEditViewModel
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEditTransferScreen(vm: AddEditViewModel, id: Long?, onBack: () -> Unit) {
    val state by vm.formState.collectAsState()
    val accounts by vm.accounts.collectAsState(initial = emptyList())
    val savedNames by vm.savedNames.collectAsState(initial = emptyList())
    val snackbar = remember { SnackbarHostState() }
    var showDatePicker by remember { mutableStateOf(false) }
    var showExitConfirm by remember { mutableStateOf(false) }
    var expandedNames by remember { mutableStateOf(false) }
    var expandedAcc by remember { mutableStateOf(false) }

    LaunchedEffect(id) { id?.let { vm.loadTransfer(it) } }
    LaunchedEffect(state.savedMessage, state.errorMessage) {
        state.savedMessage?.let {
            snackbar.showSnackbar(it)
            vm.clearMessage()
            if (state.id != null) onBack()
        } ?: state.errorMessage?.let {
            snackbar.showSnackbar(it)
            vm.clearMessage()
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = { Text(if (state.id == null) "إضافة حوالة" else "تعديل حوالة") },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, null) } },
                actions = {
                    IconButton(onClick = { if (state.hasChanges) showExitConfirm = true else onBack() }) {
                        Icon(Icons.Default.Close, null)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Black, titleContentColor = White, navigationIconContentColor = White, actionIconContentColor = White)
            )
        },
        bottomBar = {
            Row(modifier = Modifier.fillMaxWidth().background(DarkGray).padding(8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(
                    onClick = { vm.save() }, 
                    modifier = Modifier.weight(1f), 
                    enabled = !state.isLoading,
                    colors = ButtonDefaults.buttonColors(containerColor = GreenAccent)
                ) { 
                    if (state.isLoading) {
                        CircularProgressIndicator(modifier = Modifier.size(20.dp), color = Black, strokeWidth = 2.dp)
                    } else {
                        Text("حفظ", color = Black) 
                    }
                }
                OutlinedButton(onClick = { vm.clearForm() }, modifier = Modifier.weight(1f), enabled = !state.isLoading) { Text("إلغاء") }
            }
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize().background(Black).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = state.type == TransferType.RECEIVED, onClick = { vm.updateType(TransferType.RECEIVED) }, label = { Text("مستلم") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = GreenAccent, selectedLabelColor = Black))
                FilterChip(selected = state.type == TransferType.PAID, onClick = { vm.updateType(TransferType.PAID) }, label = { Text("مدفوع") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = RedAccent, selectedLabelColor = White))
            }

            Box {
                OutlinedTextField(
                    value = state.recipientName, 
                    onValueChange = { vm.updateRecipient(it); expandedNames = it.isNotEmpty() }, 
                    label = { Text("اسم المستلم *") }, modifier = Modifier.fillMaxWidth(), 
                    colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White),
                    trailingIcon = { IconButton(onClick = { expandedNames = !expandedNames }) { Icon(Icons.Default.ArrowDropDown, null) } },
                    isError = state.nameError,
                    supportingText = if (state.nameError) { { Text("الاسم مطلوب", color = RedAccent) } } else null
                )
                DropdownMenu(expanded = expandedNames, onDismissRequest = { expandedNames = false }) {
                    savedNames.filter { it.name.contains(state.recipientName, ignoreCase = true) }.forEach { s ->
                        DropdownMenuItem(text = { Text(s.name) }, onClick = { vm.updateRecipient(s.name); expandedNames = false })
                    }
                }
            }

            OutlinedTextField(
                value = state.amount, 
                onValueChange = vm::updateAmount, 
                label = { Text("المبلغ *") }, 
                modifier = Modifier.fillMaxWidth(), 
                colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White),
                isError = state.amountError,
                supportingText = if (state.amountError) { { Text("يجب أن يكون المبلغ رقماً أكبر من 0", color = RedAccent) } } else null
            )

            Box {
                OutlinedButton(
                    onClick = { expandedAcc = true }, 
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.outlinedButtonColors(
                        contentColor = if (state.accountError) RedAccent else White
                    )
                ) {
                    Text(accounts.find { it.id == state.accountId }?.name ?: "اختر الحساب *", color = if (state.accountError) RedAccent else White)
                }
                DropdownMenu(expanded = expandedAcc, onDismissRequest = { expandedAcc = false }) {
                    accounts.forEach { a ->
                        DropdownMenuItem(text = { Text(a.name) }, onClick = { vm.updateAccount(a.id); expandedAcc = false })
                    }
                }
            }
            if (state.accountError) {
                Text("يجب اختيار حساب", color = RedAccent, style = MaterialTheme.typography.bodySmall)
            }

            if (state.type == TransferType.PAID) {
                OutlinedTextField(value = state.commission, onValueChange = vm::updateCommission, label = { Text("العمولة") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))
            }

            OutlinedButton(onClick = { showDatePicker = true }, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Default.DateRange, null); Spacer(Modifier.width(8.dp))
                Text(SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date(state.date)), color = White)
            }
            OutlinedTextField(value = state.note, onValueChange = vm::updateNote, label = { Text("ملاحظة") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))

            if (showDatePicker) {
                val dateState = rememberDatePickerState(initialSelectedDateMillis = state.date)
                DatePickerDialog(
                    onDismissRequest = { showDatePicker = false },
                    confirmButton = { TextButton(onClick = { dateState.selectedDateMillis?.let { vm.updateDate(it) }; showDatePicker = false }) { Text("موافق") } },
                    dismissButton = { TextButton(onClick = { showDatePicker = false }) { Text("إلغاء") } }
                ) { DatePicker(state = dateState) }
            }
        }

        if (showExitConfirm) {
            AlertDialog(
                onDismissRequest = { showExitConfirm = false },
                title = { Text("تنبيه") },
                text = { Text("يوجد بيانات لم يتم حفظها. هل تريد الخروج؟") },
                confirmButton = { TextButton(onClick = { showExitConfirm = false; onBack() }) { Text("خروج", color = RedAccent) } },
                dismissButton = { TextButton(onClick = { showExitConfirm = false }) { Text("بقاء") } }
            )
        }
    }
}
