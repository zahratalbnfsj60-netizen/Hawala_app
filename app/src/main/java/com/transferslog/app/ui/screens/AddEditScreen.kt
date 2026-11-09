package com.transferslog.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.transferslog.app.data.Transfer
import com.transferslog.app.data.TransferType
import com.transferslog.app.ui.MainViewModel
import com.transferslog.app.ui.theme.*
import com.transferslog.app.util.AppPrefs
import com.transferslog.app.util.formatDate
import com.transferslog.app.util.toStartOfDay

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEditScreen(vm: MainViewModel, initialType: String, transferId: Long?, onClose: () -> Unit) {
    val ctx = LocalContext.current
    LaunchedEffect(Unit) { AppPrefs.init(ctx) }
    val recentNames by vm.recentNames.collectAsStateWithLifecycle()

    var existing by remember { mutableStateOf<Transfer?>(null) }
    var loaded by remember { mutableStateOf(transferId == null) }
    LaunchedEffect(transferId) { if (transferId != null) { existing = vm.getTransfer(transferId); loaded = true } }

    var type by remember { mutableStateOf(initialType) }
    var name by remember { mutableStateOf("") }
    var amount by remember { mutableStateOf("") }
    var commission by remember { mutableStateOf("") }
    var date by remember { mutableStateOf(toStartOfDay(System.currentTimeMillis())) }
    var nameError by remember { mutableStateOf(false) }
    var amountError by remember { mutableStateOf(false) }
    var showDeleteDialog by remember { mutableStateOf(false) }
    var showSuggestions by remember { mutableStateOf(false) }
    var showDatePicker by remember { mutableStateOf(false) }
    val datePickerState = rememberDatePickerState(initialSelectedDateMillis = date)

    LaunchedEffect(existing) {
        existing?.let {
            type = it.type; name = it.recipientName; amount = it.amount.toString()
            commission = if (it.commission > 0) it.commission.toString() else ""
            date = toStartOfDay(it.date)
        }
    }

    val isPaid = type == TransferType.PAID
    val quickComms = listOf(AppPrefs.comm1State.value, AppPrefs.comm2State.value)

    Scaffold(
        containerColor = Black,
        topBar = {
            TopAppBar(
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Black),
                title = { Text(if (transferId == null) "إضافة حوالة" else "تعديل حوالة", color = White) },
                navigationIcon = { IconButton(onClick = onClose) { Icon(Icons.Default.Close, null, tint = White) } },
                actions = { if (existing != null) IconButton(onClick = { showDeleteDialog = true }) { Icon(Icons.Default.Delete, null, tint = RedBright) } }
            )
        }
    ) { padding ->
        if (!loaded) return@Scaffold
        Column(Modifier.padding(padding).fillMaxSize()) {
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Box(Modifier.weight(1f).height(56.dp).clip(RoundedCornerShape(12.dp)).background(if (!isPaid) GreenBright else CardDark).border(2.dp, GreenBright, RoundedCornerShape(12.dp)).clickable { type = TransferType.RECEIVED }, contentAlignment = Alignment.Center) { Text("مستلم", color = if (!isPaid) Black else GreenBright, fontSize = 18.sp, fontWeight = FontWeight.Bold) }
                    Box(Modifier.weight(1f).height(56.dp).clip(RoundedCornerShape(12.dp)).background(if (isPaid) RedBright else CardDark).border(2.dp, RedBright, RoundedCornerShape(12.dp)).clickable { type = TransferType.PAID }, contentAlignment = Alignment.Center) { Text("مدفوع", color = if (isPaid) Black else RedBright, fontSize = 18.sp, fontWeight = FontWeight.Bold) }
                }
                Spacer(Modifier.height(16.dp))

                OutlinedTextField(
                    value = name, onValueChange = { name = it; nameError = false; showSuggestions = it.isNotBlank() },
                    label = { Text("اسم المستلم") }, isError = nameError, singleLine = true, modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(focusedContainerColor = CardDark, unfocusedContainerColor = CardDark, focusedBorderColor = GreenBright, unfocusedBorderColor = CardDark2, focusedTextColor = White, unfocusedTextColor = White, focusedLabelColor = GreenBright, unfocusedLabelColor = GrayText, cursorColor = GreenBright)
                )
                if (nameError) Text("الاسم مطلوب", color = RedBright, fontSize = 12.sp)
                if (showSuggestions) {
                    val sugg = recentNames.filter { it.name.contains(name, true) && it.name != name }.take(6)
                    if (sugg.isNotEmpty()) {
                        Spacer(Modifier.height(4.dp))
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            items(sugg) { s -> Box(Modifier.clip(RoundedCornerShape(20.dp)).background(CardDark2).clickable { name = s.name; showSuggestions = false }.padding(horizontal = 12.dp, vertical = 6.dp)) { Text(s.name, color = White, fontSize = 12.sp) } }
                        }
                    }
                }
                Spacer(Modifier.height(12.dp))

                OutlinedTextField(
                    value = amount, onValueChange = { amount = it.filter { c -> c.isDigit() || c == '.' }; amountError = false },
                    label = { Text("المبلغ") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), isError = amountError, singleLine = true, modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(focusedContainerColor = CardDark, unfocusedContainerColor = CardDark, focusedBorderColor = GreenBright, unfocusedBorderColor = CardDark2, focusedTextColor = White, unfocusedTextColor = White, focusedLabelColor = GreenBright, unfocusedLabelColor = GrayText, cursorColor = GreenBright)
                )
                if (amountError) Text("المبلغ يجب أن يكون أكبر من 0", color = RedBright, fontSize = 12.sp)
                Spacer(Modifier.height(12.dp))

                if (isPaid) {
                    OutlinedTextField(
                        value = commission, onValueChange = { commission = it.filter { c -> c.isDigit() || c == '.' } },
                        label = { Text("العمولة") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true, modifier = Modifier.fillMaxWidth(),
                        colors = OutlinedTextFieldDefaults.colors(focusedContainerColor = CardDark, unfocusedContainerColor = CardDark, focusedBorderColor = GreenBright, unfocusedBorderColor = CardDark2, focusedTextColor = White, unfocusedTextColor = White, focusedLabelColor = GreenBright, unfocusedLabelColor = GrayText, cursorColor = GreenBright)
                    )
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        quickComms.forEach { q -> OutlinedButton(onClick = { commission = q.toString() }, colors = ButtonDefaults.outlinedButtonColors(contentColor = GreenBright), border = androidx.compose.foundation.BorderStroke(1.dp, GreenBright)) { Text("$q") } }
                    }
                    Spacer(Modifier.height(12.dp))
                }

                Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(4.dp)).border(1.dp, CardDark2, RoundedCornerShape(4.dp)).clickable { showDatePicker = true }.padding(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.CalendarToday, null, tint = GrayText)
                        Spacer(Modifier.width(8.dp))
                        Column { Text("التاريخ", color = GrayText, fontSize = 12.sp); Text(formatDate(date), color = White, fontSize = 15.sp) }
                    }
                }
            }

            Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(onClick = onClose, modifier = Modifier.weight(1f).height(52.dp), colors = ButtonDefaults.outlinedButtonColors(contentColor = GrayText), border = androidx.compose.foundation.BorderStroke(1.dp, CardDark2)) { Text("إلغاء") }
                Button(
                    onClick = {
                        val amt = amount.toDoubleOrNull() ?: 0.0
                        val comm = commission.toDoubleOrNull() ?: 0.0
                        nameError = name.isBlank(); amountError = amt <= 0.0
                        if (!nameError && !amountError) vm.saveTransfer(existing, type, name, amt, comm, date, onDone = onClose)
                    },
                    modifier = Modifier.weight(1f).height(52.dp), colors = ButtonDefaults.buttonColors(containerColor = if (isPaid) RedBright else GreenBright)
                ) { Text("حفظ", color = Black, fontWeight = FontWeight.Bold, fontSize = 16.sp) }
            }
        }
    }

    if (showDatePicker) {
        DatePickerDialog(onDismissRequest = { showDatePicker = false }, confirmButton = { TextButton(onClick = { datePickerState.selectedDateMillis?.let { date = toStartOfDay(it) }; showDatePicker = false }) { Text("موافق", color = GreenBright) } }, dismissButton = { TextButton(onClick = { showDatePicker = false }) { Text("إلغاء", color = GrayText) } }) { DatePicker(state = datePickerState) }
    }

    if (showDeleteDialog) {
        AlertDialog(onDismissRequest = { showDeleteDialog = false }, containerColor = CardDark, title = { Text("تأكيد الحذف", color = White) }, text = { Text("هل تريد حذف هذه الحوالة نهائياً؟", color = GrayText) }, confirmButton = { TextButton(onClick = { existing?.let { vm.deleteTransfer(it) }; showDeleteDialog = false; onClose() }) { Text("حذف", color = RedBright) } }, dismissButton = { TextButton(onClick = { showDeleteDialog = false }) { Text("إلغاء", color = GrayText) } })
    }
}
