package com.transferslog.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
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
import com.transferslog.app.ui.theme.*
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
    var filterAccount by remember { mutableStateOf<Int?>(null) }
    var showAccountMenu by remember { mutableStateOf(false) }

    val filtered = transfers.filter { t ->
        (filterType == null || t.type == filterType) &&
        (filterAccount == null || t.accountId == filterAccount) &&
        (search.isBlank() || t.recipientName.contains(search, true) || t.amount.toString().contains(search))
    }

    val statsTransfers = if (filterAccount == null) transfers else transfers.filter { it.accountId == filterAccount }
    val totalReceived = statsTransfers.filter { it.type == TransferType.RECEIVED }.sumOf { it.amount }
    val totalPaid = statsTransfers.filter { it.type == TransferType.PAID }.sumOf { it.amount }
    val openingBalance = if (filterAccount == null) accounts.sumOf { it.openingBalance }
                         else accounts.firstOrNull { it.id == filterAccount }?.openingBalance ?: 0.0

    Scaffold(
        containerColor = BlackBg,
        topBar = {
            TopAppBar(
                title = { Text("سجل الحوالات", fontWeight = FontWeight.Bold) },
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
                    containerColor = DarkSurface,
                    titleContentColor = WhiteText,
                    actionIconContentColor = GreenBright
                )
            )
        },
        bottomBar = {
            Column(Modifier.background(DarkSurface)) {
                HorizontalDivider(color = DividerGray, thickness = 1.dp)
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Button(
                        onClick = { nav.navigate("add/RECEIVED/0") },
                        modifier = Modifier.weight(1f).height(50.dp),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = GreenReceived,
                            contentColor = BlackBg
                        )
                    ) {
                        Icon(Icons.Default.Add, null, modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("مستلم +", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                    }
                    Button(
                        onClick = { nav.navigate("add/PAID/0") },
                        modifier = Modifier.weight(1f).height(50.dp),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = RedPaid,
                            contentColor = WhiteText
                        )
                    ) {
                        Icon(Icons.Default.Add, null, modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("مدفوع +", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                    }
                }
                BottomStatsBar(
                    opening = openingBalance,
                    paid = totalPaid,
                    received = totalReceived
                )
            }
        }
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize().background(BlackBg)) {
            OutlinedTextField(
                value = search,
                onValueChange = { search = it },
                placeholder = { Text("بحث بالاسم أو المبلغ...", color = GrayText) },
                modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp),
                leadingIcon = { Icon(Icons.Default.Search, null, tint = GreenBright) },
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = GreenBright,
                    unfocusedBorderColor = DividerGray,
                    focusedContainerColor = DarkCard,
                    unfocusedContainerColor = DarkCard,
                    focusedTextColor = WhiteText,
                    unfocusedTextColor = WhiteText,
                    cursorColor = GreenBright
                )
            )

            Row(
                Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                FilterChip(
                    selected = filterType == null,
                    onClick = { filterType = null },
                    label = { Text("الكل") },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = GreenReceived,
                        selectedLabelColor = BlackBg,
                        containerColor = DarkCard,
                        labelColor = WhiteText
                    )
                )
                FilterChip(
                    selected = filterType == TransferType.RECEIVED,
                    onClick = { filterType = TransferType.RECEIVED },
                    label = { Text("مستلم") },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = GreenReceived,
                        selectedLabelColor = BlackBg,
                        containerColor = DarkCard,
                        labelColor = WhiteText
                    )
                )
                FilterChip(
                    selected = filterType == TransferType.PAID,
                    onClick = { filterType = TransferType.PAID },
                    label = { Text("مدفوع") },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = RedPaid,
                        selectedLabelColor = WhiteText,
                        containerColor = DarkCard,
                        labelColor = WhiteText
                    )
                )
                Spacer(Modifier.weight(1f))
                Box {
                    AssistChip(
                        onClick = { showAccountMenu = !showAccountMenu },
                        label = {
                            Text(
                                if (filterAccount == null) "كل الحسابات"
                                else accounts.firstOrNull { it.id == filterAccount }?.name ?: "حساب",
                                fontSize = 12.sp
                            )
                        },
                        leadingIcon = {
                            Icon(Icons.Default.AccountCircle, null, tint = GreenBright, modifier = Modifier.size(16.dp))
                        },
                        colors = AssistChipDefaults.assistChipColors(
                            containerColor = DarkCard,
                            labelColor = WhiteText
                        )
                    )
                    DropdownMenu(
                        expanded = showAccountMenu,
                        onDismissRequest = { showAccountMenu = false },
                        modifier = Modifier.background(DarkCardElevated)
                    ) {
                        DropdownMenuItem(
                            text = { Text("كل الحسابات", color = WhiteText) },
                            onClick = { filterAccount = null; showAccountMenu = false }
                        )
                        accounts.forEach { acc ->
                            DropdownMenuItem(
                                text = { Text(acc.name, color = WhiteText) },
                                onClick = { filterAccount = acc.id; showAccountMenu = false }
                            )
                        }
                    }
                }
            }

            if (filtered.isEmpty()) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            Icons.Default.Inbox, null,
                            tint = GrayText,
                            modifier = Modifier.size(72.dp)
                        )
                        Spacer(Modifier.height(12.dp))
                        Text("لا توجد حوالات", color = GrayText, fontSize = 18.sp)
                        Text("أضف حوالة من الأزرار أدناه", color = GrayText, fontSize = 13.sp)
                    }
                }
            } else {
                LazyColumn(
                    Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
                ) {
                    items(filtered, key = { it.id }) { t ->
                        val accountName = accounts.firstOrNull { it.id == t.accountId }?.name ?: ""
                        TransferCard(t, accountName, vm.settings.currency) {
                            nav.navigate("add/${t.type.name}/${t.id}")
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun BottomStatsBar(opening: Double, paid: Double, received: Double) {
    Row(
        Modifier
            .fillMaxWidth()
            .background(DarkCardElevated)
            .padding(vertical = 12.dp, horizontal = 6.dp),
        horizontalArrangement = Arrangement.SpaceEvenly
    ) {
        StatItem("الافتتاحي", opening, GoldProfit)
        VerticalDivider(color = DividerGray, modifier = Modifier.height(32.dp))
        StatItem("المدفوع", paid, RedBright)
        VerticalDivider(color = DividerGray, modifier = Modifier.height(32.dp))
        StatItem("المستلم", received, GreenBright)
    }
}

@Composable
fun StatItem(label: String, value: Double, valueColor: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, fontSize = 11.sp, color = GrayText, fontWeight = FontWeight.Medium)
        Text(
            formatCompact(value),
            fontSize = 15.sp, fontWeight = FontWeight.Bold,
            color = valueColor, textAlign = TextAlign.Center
        )
    }
}

fun formatCompact(v: Double): String = if (v == v.toLong().toDouble())
    String.format(Locale.US, "%,d", v.toLong())
else String.format(Locale.US, "%,.2f", v)

fun formatFull(v: Double, currency: String): String = "${formatCompact(v)} $currency"

@Composable
fun TransferCard(t: Transfer, accountName: String, currency: String, onClick: () -> Unit) {
    val isPaid = t.type == TransferType.PAID
    val color = if (isPaid) RedPaid else GreenReceived
    Card(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp, vertical = 4.dp)
            .border(1.dp, color.copy(alpha = 0.3f), RoundedCornerShape(12.dp)),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = DarkCard)
    ) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .background(color.copy(alpha = 0.15f), RoundedCornerShape(8.dp))
                    .padding(horizontal = 10.dp, vertical = 6.dp)
            ) {
                Text(
                    if (isPaid) "مدفوع" else "مستلم",
                    color = color, fontWeight = FontWeight.Bold, fontSize = 12.sp
                )
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(t.recipientName, color = WhiteText, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                Row {
                    Text("${formatFull(t.amount, currency)}", color = color, fontSize = 13.sp)
                    if (isPaid && t.commission > 0) {
                        Text(" • عمولة ${formatCompact(t.commission)}", color = GrayText, fontSize = 11.sp)
                    }
                }
                Text(
                    SimpleDateFormat("yyyy/MM/dd", Locale.getDefault()).format(Date(t.date)) +
                            " • $accountName" +
                            (if (isPaid && t.paidNumber != null) " • #${t.paidNumber}" else ""),
                    color = GrayText, fontSize = 11.sp
                )
                if (!t.note.isNullOrBlank()) {
                    Text("📝 ${t.note}", color = GrayText, fontSize = 11.sp)
                }
            }
            Icon(Icons.Default.ChevronLeft, null, tint = GrayText)
        }
    }
}
