package com.transferslog.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
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
import com.transferslog.app.data.Account
import com.transferslog.app.data.AccountWithBalance
import com.transferslog.app.ui.MainViewModel
import com.transferslog.app.ui.theme.*
import com.transferslog.app.util.AppPrefs
import com.transferslog.app.util.formatNum

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountsScreen(vm: MainViewModel, onBack: () -> Unit) {
    val accounts by vm.accountsWithBalance.collectAsStateWithLifecycle()
    val ctx = LocalContext.current
    LaunchedEffect(Unit) { AppPrefs.init(ctx) }
    val currency = AppPrefs.currencyState.value

    var showDialog by remember { mutableStateOf(false) }
    var editing by remember { mutableStateOf<Account?>(null) }
    var toDelete by remember { mutableStateOf<AccountWithBalance?>(null) }
    var dName by remember { mutableStateOf("") }
    var dOpening by remember { mutableStateOf("") }
    var err by remember { mutableStateOf(false) }

    Scaffold(
        containerColor = Black,
        topBar = {
            TopAppBar(
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Black),
                title = { Text("الحسابات", color = White) },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowForward, null, tint = White) } },
                actions = { IconButton(onClick = { editing = null; dName = ""; dOpening = ""; showDialog = true }) { Icon(Icons.Default.Add, null, tint = GreenBright) } }
            )
        }
    ) { padding ->
        if (accounts.isEmpty()) {
            Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Default.AccountBalanceWallet, null, tint = CardDark2, modifier = Modifier.size(80.dp))
                    Spacer(Modifier.height(12.dp))
                    Text("لا توجد حسابات", color = White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                    Spacer(Modifier.height(6.dp))
                    Text("اضغط + لإنشاء حساب جديد", color = GrayText)
                }
            }
        } else {
            LazyColumn(contentPadding = PaddingValues(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(padding)) {
                items(accounts, key = { it.id }) { a ->
                    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(CardDark).border(1.dp, CardDark2, RoundedCornerShape(12.dp)).padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(a.name, color = White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                            Spacer(Modifier.height(4.dp))
                            Text("الرصيد: ${formatNum(a.balance)} $currency", color = if (a.balance >= 0) GreenBright else RedBright, fontSize = 14.sp)
                        }
                        IconButton(onClick = { editing = Account(a.id, a.name, a.openingBalance, a.createdAt); dName = a.name; dOpening = a.openingBalance.toString(); showDialog = true }) { Icon(Icons.Default.Edit, null, tint = GrayText) }
                        IconButton(onClick = { toDelete = a }) { Icon(Icons.Default.Delete, null, tint = RedBright) }
                    }
                }
            }
        }
    }

    if (showDialog) {
        AlertDialog(
            onDismissRequest = { showDialog = false }, containerColor = CardDark, title = { Text(if (editing == null) "حساب جديد" else "تعديل الحساب", color = White) },
            text = {
                Column {
                    OutlinedTextField(value = dName, onValueChange = { dName = it; err = false }, label = { Text("اسم الحساب") }, isError = err, singleLine = true, colors = OutlinedTextFieldDefaults.colors(focusedContainerColor = CardDark2, unfocusedContainerColor = CardDark2, focusedTextColor = White, unfocusedTextColor = White, focusedBorderColor = GreenBright, unfocusedBorderColor = CardDark2, cursorColor = GreenBright))
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(value = dOpening, onValueChange = { dOpening = it.filter { c -> c.isDigit() || c == '.' } }, label = { Text("الرصيد الافتتاحي") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true, colors = OutlinedTextFieldDefaults.colors(focusedContainerColor = CardDark2, unfocusedContainerColor = CardDark2, focusedTextColor = White, unfocusedTextColor = White, focusedBorderColor = GreenBright, unfocusedBorderColor = CardDark2, cursorColor = GreenBright))
                    if (err) Text("الاسم مطلوب", color = RedBright, fontSize = 12.sp)
                }
            },
            confirmButton = { TextButton(onClick = { if (dName.isBlank()) { err = true; return@TextButton }; val ob = dOpening.toDoubleOrNull() ?: 0.0; if (editing == null) vm.insertAccount(dName, ob) else vm.updateAccount(editing!!.copy(name = dName.trim(), openingBalance = ob)); showDialog = false }) { Text("حفظ", color = GreenBright) } },
            dismissButton = { TextButton(onClick = { showDialog = false }) { Text("إلغاء", color = GrayText) } }
        )
    }

    if (toDelete != null) {
        AlertDialog(
            onDismissRequest = { toDelete = null }, containerColor = CardDark, title = { Text("حذف الحساب", color = White) },
            text = { Text("سيتم حذف الحساب «${toDelete!!.name}» وجميع حوالاته نهائياً. هل أنت متأكد؟", color = GrayText) },
            confirmButton = { TextButton(onClick = { vm.deleteAccount(Account(toDelete!!.id, toDelete!!.name, toDelete!!.openingBalance, toDelete!!.createdAt)); toDelete = null }) { Text("حذف", color = RedBright) } },
            dismissButton = { TextButton(onClick = { toDelete = null }) { Text("إلغاء", color = GrayText) } }
        )
    }
}
