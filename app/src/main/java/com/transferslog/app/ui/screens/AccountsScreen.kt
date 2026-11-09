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
import com.transferslog.app.data.Account
import com.transferslog.app.data.TransferType
import com.transferslog.app.viewmodel.MainViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountsScreen(vm: MainViewModel, nav: NavController) {
    val accounts by vm.accounts.collectAsState()
    val transfers by vm.transfers.collectAsState()
    var showAdd by remember { mutableStateOf(false) }
    var editAccount by remember { mutableStateOf<Account?>(null) }
    var deleteAccount by remember { mutableStateOf<Account?>(null) }
    var forceDelete by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("الحسابات") },
                navigationIcon = {
                    IconButton(onClick = { nav.popBackStack() }) {
                        Icon(Icons.Default.ArrowBack, "رجوع", tint = Color.White)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = Color.White
                )
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { showAdd = true },
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = Color.White
            ) { Icon(Icons.Default.Add, "إضافة") }
        }
    ) { padding ->
        if (accounts.isEmpty()) {
            Box(Modifier.padding(padding).fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("لا توجد حسابات. أضف حساباً أولاً.")
            }
        } else {
            LazyColumn(Modifier.padding(padding).fillMaxSize()) {
                items(accounts, key = { it.id }) { acc ->
                    val accTransfers = transfers.filter { it.accountId == acc.id }
                    val received = accTransfers.filter { it.type == TransferType.RECEIVED }.sumOf { it.amount }
                    val paid = accTransfers.filter { it.type == TransferType.PAID }.sumOf { it.amount }
                    val comm = accTransfers.filter { it.type == TransferType.PAID }.sumOf { it.commission }
                    val balance = acc.openingBalance + received - paid - comm

                    Card(modifier = Modifier.fillMaxWidth().padding(8.dp)) {
                        Column(Modifier.padding(12.dp)) {
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                Text(acc.name, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                                Row {
                                    IconButton(onClick = { editAccount = acc }) {
                                        Icon(Icons.Default.Edit, "تعديل")
                                    }
                                    IconButton(onClick = { deleteAccount = acc }) {
                                        Icon(Icons.Default.Delete, "حذف", tint = MaterialTheme.colorScheme.error)
                                    }
                                }
                            }
                            Text("الرصيد الافتتاحي: ${acc.openingBalance} ل.س")
                            Text("الرصيد الحالي: $balance ل.س", fontWeight = FontWeight.Bold)
                            Text("عدد الحوالات: ${accTransfers.size}", style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
        }
    }

    if (showAdd || editAccount != null) {
        var name by remember { mutableStateOf(editAccount?.name ?: "") }
        var opening by remember { mutableStateOf(editAccount?.openingBalance?.toString() ?: "0") }
        AlertDialog(
            onDismissRequest = { showAdd = false; editAccount = null },
            title = { Text(if (editAccount == null) "إضافة حساب" else "تعديل حساب") },
            text = {
                Column {
                    OutlinedTextField(
                        value = name,
                        onValueChange = { name = it },
                        label = { Text("اسم الحساب") },
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(
                        value = opening,
                        onValueChange = { opening = it.filter { c -> c.isDigit() || c == '.' || c == '-' } },
                        label = { Text("الرصيد الافتتاحي") },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    val ob = opening.toDoubleOrNull() ?: 0.0
                    if (editAccount == null) {
                        vm.addAccount(name.trim(), ob) { showAdd = false }
                    } else {
                        vm.updateAccount(editAccount!!.copy(name = name.trim(), openingBalance = ob))
                        editAccount = null
                    }
                }) { Text("حفظ") }
            },
            dismissButton = {
                TextButton(onClick = { showAdd = false; editAccount = null }) { Text("إلغاء") }
            }
        )
    }

    if (deleteAccount != null) {
        AlertDialog(
            onDismissRequest = { deleteAccount = null; forceDelete = false },
            title = { Text(if (forceDelete) "حذف الكل" else "حذف حساب") },
            text = {
                Text(
                    if (forceDelete) "سيتم حذف الحساب وجميع حوالاته. متأكد؟"
                    else "هل تريد حذف الحساب \"${deleteAccount!!.name}\"؟"
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    val acc = deleteAccount!!
                    if (forceDelete) {
                        vm.forceDeleteAccount(acc)
                        deleteAccount = null; forceDelete = false
                    } else {
                        vm.deleteAccount(acc) { ok ->
                            if (!ok) forceDelete = true else deleteAccount = null
                        }
                    }
                }) { Text("حذف", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { deleteAccount = null; forceDelete = false }) { Text("إلغاء") }
            }
        )
    }
}
