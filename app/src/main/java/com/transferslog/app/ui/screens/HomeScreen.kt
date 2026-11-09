package com.transferslog.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.transferslog.app.data.Transfer
import com.transferslog.app.data.TransferType
import com.transferslog.app.ui.MainViewModel
import com.transferslog.app.ui.components.StatCard
import com.transferslog.app.ui.theme.*
import com.transferslog.app.util.AppPrefs
import com.transferslog.app.util.formatNum
import com.transferslog.app.util.formatDate

enum class Filter { ALL, RECEIVED, PAID }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    vm: MainViewModel,
    onOpenAccounts: () -> Unit,
    onOpenSettings: () -> Unit,
    onAddTransfer: (String) -> Unit,
    onEditTransfer: (Long) -> Unit
) {
    val ctx = androidx.compose.ui.platform.LocalContext.current
    LaunchedEffect(Unit) { AppPrefs.init(ctx) }
    val accounts by vm.accounts.collectAsStateWithLifecycle()
    val selectedId by vm.selectedId.collectAsStateWithLifecycle()
    val selectedAccount by vm.selectedAccount.collectAsStateWithLifecycle()
    val transfers by vm.transfers.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }

    LaunchedEffect(accounts, selectedId) {
        if (selectedId == null && accounts.isNotEmpty()) vm.selectAccount(accounts.first().id)
    }
    LaunchedEffect(Unit) { vm.error.collect { snackbar.showSnackbar(it) } }

    var search by remember { mutableStateOf("") }
    var filter by remember { mutableStateOf(Filter.ALL) }
    var showDropdown by remember { mutableStateOf(false) }

    val filtered = transfers.filter { t ->
        val matchFilter = when (filter) {
            Filter.ALL -> true
            Filter.RECEIVED -> t.type == TransferType.RECEIVED
            Filter.PAID -> t.type == TransferType.PAID
        }
        val q = search.trim()
        val matchSearch = q.isEmpty() || t.recipientName.contains(q, true) || t.amount.toString().contains(q)
        matchFilter && matchSearch
    }

    val received = transfers.filter { it.type == TransferType.RECEIVED }.sumOf { it.amount }
    val paid = transfers.filter { it.type == TransferType.PAID }.sumOf { it.amount }
    val comm = transfers.filter { it.type == TransferType.PAID }.sumOf { it.commission }
    val balance = (selectedAccount?.openingBalance ?: 0.0) + received - paid - comm
    val currency = AppPrefs.currencyState.value

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        containerColor = Black,
        topBar = {
            TopAppBar(
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Black),
                title = {
                    Box {
                        Row(Modifier.clip(RoundedCornerShape(10.dp)).background(CardDark).clickable { showDropdown = true }.padding(horizontal = 12.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(selectedAccount?.name ?: "اختر حساباً", color = White, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                            Icon(Icons.Default.ArrowDropDown, null, tint = GrayText)
                        }
                        DropdownMenu(expanded = showDropdown, onDismissRequest = { showDropdown = false }) {
                            if (accounts.isEmpty()) {
                                DropdownMenuItem(text = { Text("لا توجد حسابات") }, onClick = { showDropdown = false; onOpenAccounts() })
                            }
                            accounts.forEach { acc -> DropdownMenuItem(text = { Text(acc.name) }, onClick = { vm.selectAccount(acc.id); showDropdown = false }) }
                            Divider(color = CardDark2)
                            DropdownMenuItem(text = { Text("إدارة الحسابات...", color = GreenBright) }, onClick = { showDropdown = false; onOpenAccounts() })
                        }
                    }
                },
                actions = {
                    IconButton(onClick = onOpenAccounts) { Icon(Icons.Default.AccountBalanceWallet, null, tint = White) }
                    IconButton(onClick = onOpenSettings) { Icon(Icons.Default.Settings, null, tint = White) }
                }
            )
        },
        bottomBar = {
            Column(Modifier.background(Black).padding(10.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { onAddTransfer(TransferType.RECEIVED) }, colors = ButtonDefaults.buttonColors(containerColor = GreenBright), modifier = Modifier.weight(1f).height(58.dp), shape = RoundedCornerShape(14.dp)) { Text("مستلم +", color = Black, fontSize = 18.sp, fontWeight = FontWeight.Bold) }
                    Button(onClick = { onAddTransfer(TransferType.PAID) }, colors = ButtonDefaults.buttonColors(containerColor = RedBright), modifier = Modifier.weight(1f).height(58.dp), shape = RoundedCornerShape(14.dp)) { Text("مدفوع +", color = Black, fontSize = 18.sp, fontWeight = FontWeight.Bold) }
                }
                Spacer(Modifier.height(10.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    StatCard("الرصيد", "${formatNum(balance)}\n$currency", if (balance >= 0) GreenBright else RedBright, Modifier.weight(1f))
                    StatCard("مدفوع", "${formatNum(paid)}", RedBright, Modifier.weight(1f))
                    StatCard("مستلم", "${formatNum(received)}", GreenBright, Modifier.weight(1f))
                    StatCard("حوالات", "${transfers.size}", White, Modifier.weight(1f))
                }
            }
        }
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            OutlinedTextField(
                value = search, onValueChange = { search = it },
                placeholder = { Text("بحث بالاسم أو المبلغ...", color = GrayText) },
                leadingIcon = { Icon(Icons.Default.Search, null, tint = GrayText) },
                singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(focusedContainerColor = CardDark, unfocusedContainerColor = CardDark, focusedBorderColor = CardDark2, unfocusedBorderColor = CardDark2, focusedTextColor = White, unfocusedTextColor = White, cursorColor = GreenBright),
                modifier = Modifier.fillMaxWidth().padding(12.dp)
            )
            Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("الكل" to Filter.ALL, "مستلم" to Filter.RECEIVED, "مدفوع" to Filter.PAID).forEach { (label, f) ->
                    Box(Modifier.clip(RoundedCornerShape(20.dp)).background(if (filter == f) GreenBright else CardDark).clickable { filter = f }.padding(horizontal = 16.dp, vertical = 8.dp)) {
                        Text(label, color = if (filter == f) Black else White, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                    }
                }
            }
            Spacer(Modifier.height(8.dp))

            if (accounts.isEmpty()) {
                EmptyState(Icons.Default.AccountBalanceWallet, "لا توجد حسابات بعد", "اضغط على إدارة الحسابات لإضافة حساب جديد")
            } else if (transfers.isEmpty()) {
                EmptyState(Icons.Default.Receipt, "لا توجد حوالات بعد", "ابدأ بإضافة حوالة مستلمة أو مدفوعة")
            } else if (filtered.isEmpty()) {
                EmptyState(Icons.Default.SearchOff, "لا نتائج", "جرّب تغيير البحث أو الفلتر")
            } else {
                LazyColumn(contentPadding = PaddingValues(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(filtered, key = { it.id }) { t ->
                        val isPaid = t.type == TransferType.PAID
                        val color = if (isPaid) RedBright else GreenBright
                        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(CardDark).border(1.dp, color, RoundedCornerShape(12.dp)).clickable { onEditTransfer(t.id) }.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(t.recipientName, color = White, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                                    if (isPaid && t.paidNumber > 0) {
                                        Spacer(Modifier.width(6.dp))
                                        Text("#${t.paidNumber}", color = GrayText, fontSize = 11.sp)
                                    }
                                }
                                Spacer(Modifier.height(4.dp))
                                Row {
                                    Text(formatDate(t.date), color = GrayText, fontSize = 11.sp)
                                    if (isPaid && t.commission > 0) Text("  •  عمولة: ${formatNum(t.commission)}", color = GrayText, fontSize = 11.sp)
                                }
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                Text("${formatNum(t.amount)} $currency", color = color, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                                Text(if (isPaid) "مدفوع" else "مستلم", color = color, fontSize = 11.sp)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun EmptyState(icon: androidx.compose.ui.graphics.vector.ImageVector, text: String, sub: String) {
    Column(Modifier.fillMaxSize().padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        Icon(icon, null, tint = CardDark2, modifier = Modifier.size(80.dp))
        Spacer(Modifier.height(16.dp))
        Text(text, color = White, fontWeight = FontWeight.Bold, fontSize = 18.sp, textAlign = TextAlign.Center)
        Spacer(Modifier.height(6.dp))
        Text(sub, color = GrayText, fontSize = 13.sp, textAlign = TextAlign.Center)
    }
}
