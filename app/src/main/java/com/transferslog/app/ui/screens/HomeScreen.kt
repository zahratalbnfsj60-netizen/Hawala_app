package com.transferslog.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.transferslog.app.data.TransferType
import com.transferslog.app.ui.components.StatBar
import com.transferslog.app.ui.components.TransferCard
import com.transferslog.app.ui.theme.*
import com.transferslog.app.ui.viewmodel.MainViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(vm: MainViewModel, onAdd: (TransferType) -> Unit, onEdit: (Long) -> Unit, onNavAcc: () -> Unit, onNavStats: () -> Unit, onNavSettings: () -> Unit) {
    val transfers by vm.transfers.collectAsState()
    val accounts by vm.accounts.collectAsState()
    val query by vm.searchQuery.collectAsState()
    val type by vm.selectedType.collectAsState()
    val accId by vm.selectedAccountId.collectAsState()
    val dateRange by vm.dateRange.collectAsState(initial = null)
    val acc = accounts.find { it.id == accId }

    var showDatePicker by remember { mutableStateOf(false) }
    var expandedAcc by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("سجل الحوالات", color = White) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Black),
                actions = {
                    IconButton(onClick = onNavAcc) { Icon(Icons.Default.Person, null, tint = White) }
                    IconButton(onClick = onNavStats) { Icon(Icons.Default.List, null, tint = White) }
                    IconButton(onClick = onNavSettings) { Icon(Icons.Default.Settings, null, tint = White) }
                }
            )
        },
        bottomBar = {
            Column(modifier = Modifier.background(DarkGray)) {
                Row(modifier = Modifier.fillMaxWidth().padding(8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { onAdd(TransferType.RECEIVED) }, modifier = Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = GreenAccent)) { Text("مستلم +", color = Black) }
                    Button(onClick = { onAdd(TransferType.PAID) }, modifier = Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = RedAccent)) { Text("مدفوع +", color = White) }
                }
                StatBar(
                    opening = acc?.openingBalance ?: 0.0,
                    paid = transfers.filter { it.type == TransferType.PAID }.sumOf { it.amount },
                    received = transfers.filter { it.type == TransferType.RECEIVED }.sumOf { it.amount }
                )
            }
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize().background(Black)) {
            OutlinedTextField(
                value = query, onValueChange = vm::setSearchQuery,
                modifier = Modifier.fillMaxWidth().padding(8.dp),
                placeholder = { Text("بحث بالاسم أو المبلغ...", color = SecondaryText) },
                leadingIcon = { Icon(Icons.Default.Search, null, tint = SecondaryText) },
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = GreenAccent, unfocusedBorderColor = LightGray, focusedTextColor = White, unfocusedTextColor = White),
                singleLine = true
            )
            
            Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                FilterChip(selected = type == null, onClick = { vm.setTypeFilter(null) }, label = { Text("الكل") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = GreenAccent, selectedLabelColor = Black))
                FilterChip(selected = type == TransferType.RECEIVED, onClick = { vm.setTypeFilter(TransferType.RECEIVED) }, label = { Text("مستلم") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = GreenAccent, selectedLabelColor = Black))
                FilterChip(selected = type == TransferType.PAID, onClick = { vm.setTypeFilter(TransferType.PAID) }, label = { Text("مدفوع") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = RedAccent, selectedLabelColor = White))
                
                // قائمة منسدلة للحساب
                Box(modifier = Modifier.weight(1f)) {
                    OutlinedButton(onClick = { expandedAcc = true }, modifier = Modifier.fillMaxWidth()) {
                        Text(acc?.name ?: "كل الحسابات", maxLines = 1)
                    }
                    DropdownMenu(expanded = expandedAcc, onDismissRequest = { expandedAcc = false }) {
                        DropdownMenuItem(text = { Text("كل الحسابات") }, onClick = { vm.setAccountFilter(null); expandedAcc = false })
                        accounts.forEach { a ->
                            DropdownMenuItem(text = { Text(a.name) }, onClick = { vm.setAccountFilter(a.id); expandedAcc = false })
                        }
                    }
                }
                // زر التاريخ
                IconButton(onClick = { showDatePicker = true }) {
                    Icon(Icons.Default.DateRange, null, tint = if (dateRange != null) GreenAccent else White)
                }
            }

            if (dateRange != null) {
                Text(
                    "مفلتر بالتاريخ",
                    color = GreenAccent, modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                )
            }

            LazyColumn(modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(transfers, key = { it.id }) { t ->
                    TransferCard(transfer = t, onClick = { onEdit(t.id) }, onDelete = { vm.deleteTransfer(t) })
                }
            }
        }

        if (showDatePicker) {
            val dateState = rememberDateRangePickerState()
            DatePickerDialog(
                onDismissRequest = { showDatePicker = false },
                confirmButton = {
                    TextButton(onClick = {
                        vm.setDateRange(dateState.selectedStartDateMillis, dateState.selectedEndDateMillis)
                        showDatePicker = false
                    }) { Text("موافق") }
                },
                dismissButton = {
                    TextButton(onClick = { vm.setDateRange(null, null); showDatePicker = false }) { Text("مسح الفلتر") }
                }
            ) { DateRangePicker(state = dateState) }
        }
    }
}
