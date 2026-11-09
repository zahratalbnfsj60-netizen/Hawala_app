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
import com.transferslog.app.data.Account
import com.transferslog.app.ui.theme.*
import com.transferslog.app.ui.viewmodel.AccountsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountsScreen(vm: AccountsViewModel, onBack: () -> Unit) {
    val accounts by vm.accounts.collectAsState()
    var showDialog by remember { mutableStateOf(false) }
    var name by remember { mutableStateOf("") }
    var opening by remember { mutableStateOf("") }

    Scaffold(
        topBar = { TopAppBar(title = { Text("الحسابات") }, navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, null) } }, colors = TopAppBarDefaults.topAppBarColors(containerColor = Black, titleContentColor = White, navigationIconContentColor = White)) },
        floatingActionButton = { FloatingActionButton(onClick = { showDialog = true }, containerColor = GreenAccent) { Icon(Icons.Default.Add, null, tint = Black) } }
    ) { padding ->
        LazyColumn(modifier = Modifier.padding(padding).fillMaxSize().background(Black), contentPadding = PaddingValues(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(accounts, key = { it.id }) { acc ->
                Card(colors = CardDefaults.cardColors(containerColor = LightGray), modifier = Modifier.fillMaxWidth()) {
                    Row(modifier = Modifier.padding(16.dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Column {
                            Text(acc.name, color = White)
                            Text("افتتاحي: ${acc.openingBalance}", color = SecondaryText)
                        }
                        IconButton(onClick = { vm.delete(acc) }) { Icon(Icons.Default.Delete, null, tint = RedAccent) }
                    }
                }
            }
        }
        if (showDialog) {
            AlertDialog(
                onDismissRequest = { showDialog = false },
                title = { Text("إضافة حساب") },
                text = {
                    Column {
                        OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("الاسم") })
                        OutlinedTextField(value = opening, onValueChange = { opening = it }, label = { Text("الرصيد الافتتاحي") })
                    }
                },
                confirmButton = { TextButton(onClick = { vm.add(name, opening.toDoubleOrNull() ?: 0.0); showDialog = false; name = ""; opening = "" }) { Text("حفظ") } },
                dismissButton = { TextButton(onClick = { showDialog = false }) { Text("إلغاء") } }
            )
        }
    }
}
