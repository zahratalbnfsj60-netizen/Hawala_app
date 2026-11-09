package com.transferslog.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.transferslog.app.data.*
import com.transferslog.app.ui.theme.*
import com.transferslog.app.viewmodel.MainViewModel
import kotlinx.coroutines.launch
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
    val settings = vm.settings

    var name by remember { mutableStateOf("") }
    var amount by remember { mutableStateOf("") }
    var commission by remember {
        mutableStateOf(if (settings.defaultCommissionIsFirst) settings.commission1 else settings.commission2)
    }
    var selectedAccount by remember { mutableStateOf<Int?>(null) }
    var note by remember { mutableStateOf("") }
    var date by remember { mutableStateOf(System.currentTimeMillis()) }
    var showSuggestions by remember { mutableStateOf(false) }
    var showDatePicker by remember { mutableStateOf(false) }
    var showDeleteDialog by remember { mutableStateOf(false) }
    var showExitDialog by remember { mutableStateOf(false) }

    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    var loadedId by remember { mutableStateOf(0) }
    LaunchedEffect(existing?.id) {
        if (editId != 0 && existing != null && loadedId != existing.id) {
            name = existing.recipientName
            amount = existing.amount.toString()
            commission = existing.commission
            selectedAccount = existing.accountId
            note = existing.note ?: ""
            date = existing.date
            loadedId = existing.id
        }
    }

    LaunchedEffect(accounts.size) {
        if (selectedAccount == null && accounts.isNotEmpty()) {
            selectedAccount = accounts.first().id
        }
    }

    if (showDatePicker) {
        val state = rememberDatePickerState(initialSelectedDateMillis = date)
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let { date = it }
                    showDatePicker = false
                }) { Text("موافق", color = GreenBright) }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text("إلغاء", color = GrayText) }
            },
            colors = DatePickerDefaults.colors(
                containerColor = DarkCard,
                titleContentColor = WhiteText,
                headlineContentColor = WhiteText,
                weekdayContentColor = GrayText,
                dayContentColor = WhiteText,
                selectedDayContainerColor = GreenReceived,
                selectedDayContentColor = BlackBg,
                todayContentColor = GreenBright,
                todayDateBorderColor = GreenBright
            )
        ) { DatePicker(state = state) }
    }

    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            containerColor = DarkCard,
            title = { Text("حذف الحوالة", color = WhiteText) },
            text = { Text("هل تريد حذف هذه الحوالة نهائياً؟", color = GrayText) },
            confirmButton = {
                TextButton(onClick = {
                    existing?.let { vm.deleteTransfer(it) }
                    showDeleteDialog = false
                    onBack()
                }) { Text("حذف", color = RedBright) }
            },
            dismissButton = { TextButton(onClick = { showDeleteDialog = false }) { Text("إلغاء", color = GrayText) } }
        )
    }

    if (showExitDialog) {
        AlertDialog(
            onDismissRequest = { showExitDialog = false },
            containerColor = DarkCard,
            title = { Text("الخروج؟", color = WhiteText) },
            text = { Text("ستُفقد البيانات غير المحفوظة", color = GrayText) },
            confirmButton = {
                TextButton(onClick = { showExitDialog = false; onBack() }) {
                    Text("خروج", color = RedBright)
                }
            },
            dismissButton = { TextButton(onClick = { showExitDialog = false }) { Text("بقاء", color = GreenBright) } }
        )
    }

    Scaffold(
        containerColor = BlackBg,
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        if (editId == 0) (if (isPaid) "إضافة حوالة مدفوعة" else "إضافة حوالة مستلمة")
                        else "تعديل حوالة",
                        fontWeight = FontWeight.Bold
                    )
                },
                navigationIcon = {
                    IconButton(onClick = {
                        if (editId == 0 && (name.isNotBlank() || amount.isNotBlank())) {
                            showExitDialog = true
                        } else {
                            onBack()
                        }
                    }) { Icon(Icons.Default.Close, "إغلاق", tint = WhiteText) }
                },
                actions = {
                    if (editId != 0) {
                        IconButton(onClick = { showDeleteDialog = true }) {
                            Icon(Icons.Default.Delete, "حذف", tint = RedBright)
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = if (isPaid) RedPaid.copy(alpha = 0.2f) else GreenReceived.copy(alpha = 0.2f)
                )
            )
        },
        bottomBar = {
            Surface(color = DarkSurface, shadowElevation = 8.dp) {
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    OutlinedButton(
                        onClick = {
                            if (editId == 0) {
                                name = ""; amount = ""; note = ""
                                commission = if (settings.defaultCommissionIsFirst) settings.commission1 else settings.commission2
                                scope.launch { snackbarHostState.showSnackbar("تم تفريغ النموذج") }
                            } else {
                                onBack()
                            }
                        },
                        modifier = Modifier.weight(1f).height(50.dp),
                        shape = RoundedCornerShape(12.dp),
                        border = androidx.compose.foundation.BorderStroke(1.dp, GrayText)
                    ) {
                        Text("إلغاء", color = WhiteText, fontWeight = FontWeight.Bold)
                    }
                    Button(
                        onClick = {
                            val accId = selectedAccount
                            if (name.isBlank() || amount.toDoubleOrNull() == null || accId == null) {
                                scope.launch { snackbarHostState.showSnackbar("تحقق من الحقول: الاسم، المبلغ، الحساب") }
                                return@Button
                            }
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
                            vm.saveTransfer(t) {
                                if (editId == 0) {
                                    name = ""; amount = ""; note = ""
                                    scope.launch {
                                        snackbarHostState.showSnackbar("✅ تم الحفظ - جاهز للإدخال التالي")
                                    }
                                } else {
                                    onBack()
                                }
                            }
                        },
                        modifier = Modifier.weight(1.4f).height(50.dp),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (isPaid) RedPaid else GreenReceived,
                            contentColor = if (isPaid) WhiteText else BlackBg
                        )
                    ) {
                        Icon(Icons.Default.Check, null, modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("حفظ", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                    }
                }
            }
        }
    ) { padding ->
        Column(
            Modifier.padding(padding).padding(16.dp).fillMaxSize().verticalScroll(rememberScrollState())
        ) {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it; showSuggestions = true },
                label = { Text("اسم المستلم") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                leadingIcon = { Icon(Icons.Default.Person, null, tint = GreenBright) },
                colors = customFieldColors()
            )
            if (showSuggestions && name.isNotBlank()) {
                val sugg = savedNames.filter { it.name.contains(name, true) && it.name != name }.take(3)
                sugg.forEach { sn ->
                    Surface(
                        modifier = Modifier.fillMaxWidth().padding(top = 4.dp)
                            .clickable { name = sn.name; showSuggestions = false },
                        color = DarkCard,
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Row(Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.History, null, tint = GrayText, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(8.dp))
                            Text(sn.name, color = WhiteText)
                        }
                    }
                }
            }

            Spacer(Modifier.height(12.dp))

            OutlinedTextField(
                value = amount,
                onValueChange = { amount = it.filter { c -> c.isDigit() || c == '.' } },
                label = { Text("المبلغ (${settings.currency})") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                leadingIcon = { Icon(Icons.Default.AttachMoney, null, tint = GoldProfit) },
                textStyle = androidx.compose.ui.text.TextStyle(fontSize = 18.sp, fontWeight = FontWeight.Bold),
                colors = customFieldColors()
            )

            if (isPaid) {
                Spacer(Modifier.height(16.dp))
                Text("العمولة", color = WhiteText, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(settings.commission1, settings.commission2).forEach { c ->
                        val sel = commission == c
                        Card(
                            onClick = { commission = c },
                            modifier = Modifier.weight(1f),
                            shape = RoundedCornerShape(10.dp),
                            colors = CardDefaults.cardColors(
                                containerColor = if (sel) RedPaid.copy(alpha = 0.25f) else DarkCard
                            ),
                            border = androidx.compose.foundation.BorderStroke(
                                1.dp, if (sel) RedBright else DividerGray
                            )
                        ) {
                            Row(
                                Modifier.padding(12.dp).fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                RadioButton(
                                    selected = sel,
                                    onClick = { commission = c },
                                    colors = RadioButtonDefaults.colors(
                                        selectedColor = RedBright,
                                        unselectedColor = GrayText
                                    )
                                )
                                Text(
                                    "${formatCompact(c)} ${settings.currency}",
                                    color = if (sel) RedBright else WhiteText,
                                    fontWeight = if (sel) FontWeight.Bold else FontWeight.Normal,
                                    fontSize = 14.sp
                                )
                            }
                        }
                    }
                }
            }

            Spacer(Modifier.height(12.dp))

            OutlinedButton(
                onClick = { showDatePicker = true },
                modifier = Modifier.fillMaxWidth().height(52.dp),
                shape = RoundedCornerShape(12.dp),
                border = androidx.compose.foundation.BorderStroke(1.dp, DividerGray)
            ) {
                Icon(Icons.Default.DateRange, null, tint = GreenBright)
                Spacer(Modifier.width(8.dp))
                Text(
                    SimpleDateFormat("yyyy/MM/dd", Locale.getDefault()).format(Date(date)),
                    color = WhiteText, fontSize = 15.sp
                )
            }

            Spacer(Modifier.height(12.dp))

            var expanded by remember { mutableStateOf(false) }
            ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
                OutlinedTextField(
                    value = accounts.firstOrNull { it.id == selectedAccount }?.name ?: "اختر الحساب",
                    onValueChange = {}, readOnly = true,
                    label = { Text("الحساب") },
                    leadingIcon = { Icon(Icons.Default.AccountCircle, null, tint = GreenBright) },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded, tintedIcon = GreenBright) },
                    modifier = Modifier.menuAnchor().fillMaxWidth(),
                    colors = customFieldColors()
                )
                ExposedDropdownMenu(
                    expanded = expanded,
                    onDismissRequest = { expanded = false },
                    modifier = Modifier.background(DarkCardElevated)
                ) {
                    accounts.forEach { acc ->
                        DropdownMenuItem(
                            text = { Text(acc.name, color = WhiteText) },
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
                modifier = Modifier.fillMaxWidth(),
                leadingIcon = { Icon(Icons.Default.Notes, null, tint = GrayText) },
                colors = customFieldColors()
            )

            Spacer(Modifier.height(80.dp))
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun customFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = GreenBright,
    unfocusedBorderColor = DividerGray,
    focusedTextColor = WhiteText,
    unfocusedTextColor = WhiteText,
    focusedLabelColor = GreenBright,
    unfocusedLabelColor = GrayText,
    cursorColor = GreenBright,
    focusedContainerColor = DarkCard,
    unfocusedContainerColor = DarkCard
)
