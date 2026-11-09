package com.transferslog.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import com.transferslog.app.data.TransferType
import com.transferslog.app.ui.components.TransferCard
import com.transferslog.app.ui.theme.*
import com.transferslog.app.ui.viewmodel.MainViewModel
import java.text.DecimalFormat

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(vm: MainViewModel, onAdd: (TransferType) -> Unit, onEdit: (Long) -> Unit, onNavAcc: () -> Unit, onNavSettings: () -> Unit) {
    val transfers by vm.transfers.collectAsState()
    val accounts by vm.accounts.collectAsState()
    val query by vm.searchQuery.collectAsState()
    val type by vm.selectedType.collectAsState()
    val accId by vm.selectedAccountId.collectAsState()
    
    val acc = accounts.find { it.id == accId }
    var expandedAcc by remember { mutableStateOf(false) }
    val format = DecimalFormat("#,###.##")

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Box {
                        Row(modifier = Modifier.clickable { expandedAcc = true }, verticalAlignment = Alignment.CenterVertically) {
                            Text(acc?.name ?: "اختر حساب", color = White, fontSize = 20.sp)
                            Icon(Icons.Default.ArrowDropDown, null, tint = White)
                        }
                        DropdownMenu(expanded = expandedAcc, onDismissRequest = { expandedAcc = false }) {
                            accounts.forEach { a -> DropdownMenuItem(text = { Text(a.name) }, onClick = { vm.setAccountFilter(a.id); expandedAcc = false }) }
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Black),
                actions = {
                    IconButton(onClick = onNavAcc) { Icon(Icons.Default.Person, null, tint = White) }
                    IconButton(onClick = onNavSettings) { Icon(Icons.Default.Build, null, tint = White) }
                }
            )
        },
        bottomBar = {
            Column(modifier = Modifier.background(DarkGray)) {
                Row(modifier = Modifier.fillMaxWidth().padding(8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { onAdd(TransferType.RECEIVED) }, modifier = Modifier.weight(1f).height(60.dp), colors = ButtonDefaults.buttonColors(containerColor = GreenAccent), shape = MaterialTheme.shapes.medium) { Text("مستلم +", color = Black, fontSize = 20.sp, fontWeight = FontWeight.Bold) }
                    Button(onClick = { onAdd(TransferType.PAID) }, modifier = Modifier.weight(1f).height(60.dp), colors = ButtonDefaults.buttonColors(containerColor = RedAccent), shape = MaterialTheme.shapes.medium) { Text("مدفوع +", color = White, fontSize = 20.sp, fontWeight = FontWeight.Bold) }
                }
                Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp), horizontalArrangement = Arrangement.SpaceEvenly) {
                    val received = transfers.filter { it.type == TransferType.RECEIVED }.sumOf { it.amount }
                    val paid = transfers.filter { it.type == TransferType.PAID }.sumOf { it.amount }
                    val commission = transfers.filter { it.type == TransferType.PAID }.sumOf { it.commission }
                    val opening = acc?.openingBalance ?: 0.0
                    StatItem("الرصيد", opening + received - paid - commission, if ((opening + received - paid - commission) >= 0) GreenAccent else RedAccent, format)
                    StatItem("مدفوع", paid, RedAccent, format)
                    StatItem("مستلم", received, GreenAccent, format)
                    StatItem("حوالات", transfers.size.toDouble(), White, DecimalFormat("#"))
                }
                Spacer(Modifier.height(8.dp))
            }
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize().background(Black)) {
            OutlinedTextField(value = query, onValueChange = vm::setSearchQuery, modifier = Modifier.fillMaxWidth().padding(8.dp), placeholder = { Text("بحث...", color = SecondaryText) }, leadingIcon = { Icon(Icons.Default.Search, null, tint = SecondaryText) }, colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = GreenAccent, unfocusedBorderColor = LightGray, focusedTextColor = White, unfocusedTextColor = White), singleLine = true)
            
            Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = type == null, onClick = { vm.setTypeFilter(null) }, label = { Text("الكل") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = GreenAccent, selectedLabelColor = Black))
                FilterChip(selected = type == TransferType.RECEIVED, onClick = { vm.setTypeFilter(TransferType.RECEIVED) }, label = { Text("مستلم") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = GreenAccent, selectedLabelColor = Black))
                FilterChip(selected = type == TransferType.PAID, onClick = { vm.setTypeFilter(TransferType.PAID) }, label = { Text("مدفوع") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = RedAccent, selectedLabelColor = White))
            }

            if (accId == null) { Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text("الرجاء إضافة حساب أولاً من الإعدادات", color = SecondaryText) } }
            else if (transfers.isEmpty()) { Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text("لا توجد حوالات لهذا الحساب", color = SecondaryText) } }
            else {
                LazyColumn(modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(transfers, key = { it.id }) { t -> TransferCard(transfer = t, onClick = { onEdit(t.id) }) }
                }
            }
        }
    }
}

@Composable
private fun StatItem(label: String, value: Double, color: Color, format: DecimalFormat) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, color = SecondaryText, fontSize = 10.sp)
        Text(format.format(value), color = color, fontSize = 14.sp, fontWeight = FontWeight.Bold)
    }
}
