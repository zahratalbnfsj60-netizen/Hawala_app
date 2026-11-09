package com.transferslog.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.transferslog.app.data.TransferType
import com.transferslog.app.ui.theme.*
import com.transferslog.app.ui.viewmodel.AddEditViewModel
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEditTransferScreen(vm: AddEditViewModel, id: Long?, onBack: () -> Unit) {
    val state by vm.formState.collectAsState()
    val savedNames by vm.savedNames.collectAsState(initial = emptyList())
    val snackbar = remember { SnackbarHostState() }
    var showDatePicker by remember { mutableStateOf(false) }
    var showDeleteConfirm by remember { mutableStateOf(false) }
    var expandedNames by remember { mutableStateOf(false) }

    LaunchedEffect(id) { id?.let { vm.loadTransfer(it) } }
    LaunchedEffect(state.savedMessage, state.errorMessage) {
        state.savedMessage?.let { snackbar.showSnackbar(it); vm.clearMessage(); onBack() }
            ?: state.errorMessage?.let { snackbar.showSnackbar(it); vm.clearMessage() }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = { Text(if (state.id == null) "إضافة حوالة" else "تعديل حوالة") },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, null) } },
                actions = { if (state.id != null) IconButton(onClick = { showDeleteConfirm = true }) { Icon(Icons.Default.Delete, null, tint = RedAccent) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Black, titleContentColor = White, navigationIconContentColor = White, actionIconContentColor = White)
            )
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize().background(Black).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Row(modifier = Modifier.fillMaxWidth().height(80.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(modifier = Modifier.weight(1f).fillMaxHeight().background(if (state.type == TransferType.RECEIVED) GreenAccent else DarkGray, RoundedCornerShape(12.dp)).clickable { vm.updateType(TransferType.RECEIVED) }, contentAlignment = Alignment.Center) { Text("مستلم", color = if (state.type == TransferType.RECEIVED) Black else White, fontSize = 24.sp, fontWeight = FontWeight.Bold) }
                Box(modifier = Modifier.weight(1f).fillMaxHeight().background(if (state.type == TransferType.PAID) RedAccent else DarkGray, RoundedCornerShape(12.dp)).clickable { vm.updateType(TransferType.PAID) }, contentAlignment = Alignment.Center) { Text("مدفوع", color = if (state.type == TransferType.PAID) White else White, fontSize = 24.sp, fontWeight = FontWeight.Bold) }
            }

            Box {
                OutlinedTextField(value = state.recipientName, onValueChange = { vm.updateRecipient(it); expandedNames = it.isNotEmpty() }, label = { Text("اسم المستلم") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White), trailingIcon = { IconButton(onClick = { expandedNames = !expandedNames }) { Icon(Icons.Default.ArrowDropDown, null) } }, singleLine = true)
                DropdownMenu(expanded = expandedNames, onDismissRequest = { expandedNames = false }) {
                    savedNames.filter { it.name.contains(state.recipientName, ignoreCase = true) }.forEach { s -> DropdownMenuItem(text = { Text(s.name) }, onClick = { vm.updateRecipient(s.name); expandedNames = false }) }
                }
            }

            OutlinedTextField(value = state.amount, onValueChange = { input -> vm.updateAmount(input.filter { it.isDigit() }) }, label = { Text("المبلغ") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true)

            if (state.type == TransferType.PAID) {
                OutlinedTextField(value = state.commission, onValueChange = { input -> vm.updateCommission(input.filter { it.isDigit() }) }, label = { Text("العمولة") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    AssistChip(onClick = { vm.updateCommission("100") }, label = { Text("100") }, colors = AssistChipDefaults.assistChipColors(containerColor = LightGray, labelColor = White))
                    AssistChip(onClick = { vm.updateCommission("250") }, label = { Text("250") }, colors = AssistChipDefaults.assistChipColors(containerColor = LightGray, labelColor = White))
                }
            }

            OutlinedButton(onClick = { showDatePicker = true }, modifier = Modifier.fillMaxWidth()) { Icon(Icons.Default.DateRange, null); Spacer(Modifier.width(8.dp)); Text(SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date(state.date)), color = White) }

            Spacer(Modifier.height(16.dp))

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = { vm.save() }, modifier = Modifier.weight(1f).height(50.dp), enabled = !state.isLoading, colors = ButtonDefaults.buttonColors(containerColor = GreenAccent)) { if (state.isLoading) CircularProgressIndicator(modifier = Modifier.size(24.dp), color = Black, strokeWidth = 2.dp) else Text("حفظ", color = Black, fontSize = 18.sp) }
                OutlinedButton(onClick = { vm.clearForm() }, modifier = Modifier.weight(1f).height(50.dp), enabled = !state.isLoading) { Text("إلغاء", fontSize = 18.sp) }
            }
        }

        if (showDatePicker) {
            val dateState = rememberDatePickerState(initialSelectedDateMillis = state.date)
            DatePickerDialog(onDismissRequest = { showDatePicker = false }, confirmButton = { TextButton(onClick = { dateState.selectedDateMillis?.let { vm.updateDate(it) }; showDatePicker = false }) { Text("موافق") } }, dismissButton = { TextButton(onClick = { showDatePicker = false }) { Text("إلغاء") } }) { DatePicker(state = dateState) }
        }

        if (showDeleteConfirm) {
            AlertDialog(onDismissRequest = { showDeleteConfirm = false }, title = { Text("حذف الحوالة") }, text = { Text("هل أنت متأكد من حذف هذه الحوالة؟") }, confirmButton = { TextButton(onClick = { showDeleteConfirm = false; vm.delete() }) { Text("حذف", color = RedAccent) } }, dismissButton = { TextButton(onClick = { showDeleteConfirm = false }) { Text("إلغاء") } })
        }
    }
}
