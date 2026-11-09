package com.transferslog.app.ui.screens

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
import androidx.navigation.NavController
import com.transferslog.app.data.*
import com.transferslog.app.viewmodel.MainViewModel
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(vm: MainViewModel, nav: NavController) {
    val transfers by vm.transfers.collectAsState()
    val accounts by vm.accounts.collectAsState()
    var search by remember { mutableStateOf("") }
    var filterType by remember { mutableStateOf<TransferType?>(null) }

    val filtered = transfers.filter { t ->
        (filterType == null || t.type == filterType) &&
        (search.isBlank() || t.recipientName.contains(search, true) || t.amount.toString().contains(search))
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("سجل الحوالات") },
                actions = {
                    IconButton(onClick = { nav.navigate("accounts") }) {
                        Icon(Icons.Default.AccountBalance, "الحسابات")
                    }
                    IconButton(onClick = { nav.navigate("dashboard") }) {
                        Icon(Icons.Default.BarChart, "الإحصائيات")
                    }
                    IconButton(onClick = { nav.navigate("settings") }) {
                        Icon(Icons.Default.Settings, "الإعدادات")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = Color.White,
                    actionIconContentColor = Color.White
                )
            )
        },
        floatingActionButton = {
            Column(horizontalAlignment = Alignment.End) {
                ExtendedFloatingActionButton(
                    onClick = { nav.navigate("add/RECEIVED/0") },
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = Color.White
                ) { Text("مستلم +") }
                Spacer(Modifier.height(8.dp))
                ExtendedFloatingActionButton(
                    onClick = { nav.navigate("add/PAID/0") },
                    containerColor = MaterialTheme.colorScheme.error,
                    contentColor = Color.White
                ) { Text("مدفوع +") }
            }
        }
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            OutlinedTextField(
                value = search,
                onValueChange = { search = it },
                label = { Text("بحث...") },
                modifier = Modifier.fillMaxWidth().padding(8.dp),
                leadingIcon = { Icon(Icons.Default.Search, null) }
            )
            Row(Modifier.padding(horizontal = 8.dp)) {
                FilterChip(selected = filterType == null, onClick = { filterType = null }, label = { Text("الكل") })
                Spacer(Modifier.width(8.dp))
                FilterChip(selected = filterType == TransferType.PAID, onClick = { filterType = TransferType.PAID }, label = { Text("مدفوع") })
                Spacer(Modifier.width(8.dp))
                FilterChip(selected = filterType == TransferType.RECEIVED, onClick = { filterType = TransferType.RECEIVED }, label = { Text("مستلم") })
            }
            if (filtered.isEmpty()) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text("لا توجد حوالات بعد", style = MaterialTheme.typography.titleMedium)
                }
            } else {
                LazyColumn(Modifier.fillMaxSize()) {
                    items(filtered, key = { it.id }) { t ->
                        val accountName = accounts.firstOrNull { it.id == t.accountId }?.name ?: ""
                        TransferCard(t, accountName) {
                            nav.navigate("add/${t.type.name}/${t.id}")
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun TransferCard(t: Transfer, accountName: String, onClick: () -> Unit) {
    val isPaid = t.type == TransferType.PAID
    val color = if (isPaid) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary
    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp),
        colors = CardDefaults.cardColors(containerColor = color.copy(alpha = 0.08f))
    ) {
        Column(Modifier.padding(12.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(t.recipientName, fontWeight = FontWeight.Bold)
                Text(if (isPaid) "مدفوع" else "مستلم", color = color, fontWeight = FontWeight.Bold)
            }
            Text("المبلغ: ${t.amount} ل.س")
            if (isPaid && t.commission > 0) Text("العمولة: ${t.commission} ل.س")
            Text("الحساب: $accountName")
            if (isPaid && t.paidNumber != null) Text("رقم: ${t.paidNumber}")
            Text(
                SimpleDateFormat("yyyy/MM/dd", Locale.getDefault()).format(Date(t.date)),
                style = MaterialTheme.typography.bodySmall
            )
            if (!t.note.isNullOrBlank()) {
                Text("ملاحظة: ${t.note}", style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}
