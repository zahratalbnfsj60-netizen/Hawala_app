package com.transferslog.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.transferslog.app.ui.theme.*
import com.transferslog.app.ui.viewmodel.AccountWithBalance
import com.transferslog.app.ui.viewmodel.AccountsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountsScreen(vm: AccountsViewModel, onBack: () -> Unit) {
    val accounts by vm.accountsWithBalance.collectAsState()
    var showDialog by remember { mutableStateOf(false) }
    var editAcc by remember { mutableStateOf<AccountWithBalance?>(null) }
    var name by remember { mutableStateOf("") }
    var opening by remember { mutableStateOf("") }

    Scaffold(
        topBar = { TopAppBar(title = { Text("الحسابات") }, navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, null) } }, colors = TopAppBarDefaults.topAppBarColors(containerColor = Black, titleContentColor = White, navigationIconContentColor = White)) },
        floatingActionButton = { FloatingActionButton(onClick = { editAcc = null; name = ""; opening = ""; showDialog = true }, containerColor = GreenAccent) { Icon(Icons.Default.Add, null, tint = Black) } }
    ) { padding ->
        LazyColumn(modifier = Modifier.padding(padding).fillMaxSize().background(Black), contentPadding = PaddingValues(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(accounts, key = { it.account.id }) { item ->
                Card(colors = CardDefaults.cardColors(containerColor = LightGray), modifier = Modifier.fillMaxWidth()) {
                    Row(modifier = Modifier.padding(16.dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                        Column {
                            Text(item.account.name, color = White, style = MaterialTheme.typography.titleMedium)
                            Text("الافتتاحي: ${item.account.openingBalance} | الحالي: ${item.currentBalance}", color = if (item.currentBalance >= 0) GreenAccent else RedAccent)
                        }
                        Row {
                            IconButton(onClick = { editAcc = item; name = item.account.name; opening = item.account.openingBalance.toString(); showDialog = true }) { Icon(Icons.Default.Edit, null, tint = White) }
                            IconButton(onClick = { vm.delete(item.account) }) { Icon(Icons.Default.Delete, null, tint = RedAccent) }
                        }
                    }
                }
            }
        }
        if (showDialog) {
            AlertDialog(
                onDismissRequest = { showDialog = false },
                title = { Text(if (editAcc == null) "إضافة حساب" else "تعديل حساب") },
                text = {
                    Column {
                        OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("الاسم") })
                        Spacer(Modifier.height(8.dp))
                        OutlinedTextField(value = opening, onValueChange = { opening = it }, label = { Text("الرصيد الافتتاحي") })
                    }
                },
                confirmButton = { TextButton(onClick = { 
                    val openVal = opening.toDoubleOrNull() ?: 0.0
                    if (editAcc == null) vm.add(name, openVal) else vm.update(editAcc!!.account.copy(name = name, openingBalance = openVal))
                    showDialog = false 
                }) { Text("حفظ") } },
                dismissButton = { TextButton(onClick = { showDialog = false }) { Text("إلغاء") } }
            )
        }
    }
}
