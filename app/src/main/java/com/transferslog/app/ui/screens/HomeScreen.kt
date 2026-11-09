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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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

    // حساب المجاميع للنتائج المعروضة حالياً (تتحدث مع البحث/الفلترة)
    val totalReceived = filtered.filter { it.type == TransferType.RECEIVED }.sumOf { it.amount }
    val totalPaid = filtered.filter { it.type == TransferType.PAID }.sumOf { it.amount }
    val totalCommission = filtered.filter { it.type == TransferType.PAID }.sumOf { it.commission }
    val remaining = totalReceived - totalPaid - totalCommission

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
        bottomBar = {
            Column {
                // 🔹 أزرار الإضافة السريعة (فوق الشريط السفلي)
                Row(
                    Modifier
                        .fillMaxWidth()
                        .background(MaterialTheme.colorScheme.surface)
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Button(
                        onClick = { nav.navigate("add/RECEIVED/0") },
                        modifier = Modifier.weight(1f).height(48.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.primary
                        )
                    ) {
                        Icon(Icons.Default.Add, null)
                        Spacer(Modifier.width(4.dp))
                        Text("مستلم +", fontWeight = FontWeight.Bold)
                    }
                    Button(
                        onClick = { nav.navigate("add/PAID/0") },
                        modifier = Modifier.weight(1f).height(48.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.error
                        )
                    ) {
                        Icon(Icons.Default.Add, null)
                        Spacer(Modifier.width(4.dp))
                        Text("مدفوع +", fontWeight = FontWeight.Bold)
                    }
                }

                // 🔹 شريط الإحصائيات السفلي
                BottomStatsBar(
                    received = totalReceived,
                    paid = totalPaid,
                    remaining = remaining,
                    profit = totalCommission
                )
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

// شريط الإحصائيات السفلي
@Composable
fun BottomStatsBar(received: Double, paid: Double, remaining: Double, profit: Double) {
    Surface(
        color = Color(0xFF1B5E20),
        tonalElevation = 8.dp,
        shadowElevation = 8.dp
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(vertical = 10.dp, horizontal = 4.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            StatItem("مستلم", received, Color(0xFF69F0AE))
            VerticalDivider(color = Color.White.copy(alpha = 0.2f), modifier = Modifier.height(28.dp))
            StatItem("مدفوع", paid, Color(0xFFFF8A80))
            VerticalDivider(color = Color.White.copy(alpha = 0.2f), modifier = Modifier.height(28.dp))
            StatItem("الباقي", remaining, Color.White)
            VerticalDivider(color = Color.White.copy(alpha = 0.2f), modifier = Modifier.height(28.dp))
            StatItem("أرباح", profit, Color(0xFFFFE082))
        }
    }
}

@Composable
fun StatItem(label: String, value: Double, valueColor: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            label,
            fontSize = 11.sp,
            color = Color.White.copy(alpha = 0.75f),
            fontWeight = FontWeight.Medium
        )
        Text(
            text = formatNumber(value),
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            color = valueColor,
            textAlign = TextAlign.Center
        )
    }
}

private fun formatNumber(value: Double): String {
    return if (value == value.toLong().toDouble()) {
        value.toLong().toString()
    } else {
        String.format(Locale.getDefault(), "%.2f", value)
    }
}

// بطاقة الحوالة (كما هي)
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
