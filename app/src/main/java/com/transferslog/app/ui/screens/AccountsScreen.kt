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
import com.transferslog.app.ui.theme.*
import com.transferslog.app.ui.viewmodel.AccountWithBalance
import com.transferslog.app.ui.viewmodel.AccountsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountsScreen(vm: AccountsViewModel, onBack: () -> Unit) {
    val uiState by vm.uiState.collectAsState()
    val snackbar = remember { SnackbarHostState() }
    var showDialog by remember { mutableStateOf(false) }
    var editAcc by remember { mutableStateOf<AccountWithBalance?>(null) }
    var name by remember { mutableStateOf("") }
    var opening by remember { mutableStateOf("") }

    LaunchedEffect(uiState.errorMessage, uiState.successMessage) {
        uiState.errorMessage?.let { snackbar.showSnackbar(it); vm.clearMessages() }
        uiState.successMessage?.let { snackbar.showSnackbar(it); vm.clearMessages() }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = { 
            TopAppBar(
                title = { Text("الحسابات") }, 
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, null) } }, 
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Black, titleContentColor = White, navigationIconContentColor = White)
            ) 
        },
        floatingActionButton = { 
            FloatingActionButton(
                onClick = { editAcc = null; name = ""; opening = ""; showDialog = true }, 
                containerColor = GreenAccent
            ) { Icon(Icons.Default.Add, null, tint = Black) } 
        }
    ) { padding ->
        if (uiState.isLoading && uiState.accounts.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = GreenAccent)
            }
        } else if (uiState.accounts.isEmpty()) {
            Box(modifier = Modifier.padding(padding).fillMaxSize().background(Black), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Default.Person, null, tint = SecondaryText, modifier = Modifier.size(64.dp))
                    Spacer(Modifier.height(16.dp))
                    Text("لا توجد حسابات", color = SecondaryText, style = MaterialTheme.typography.titleMedium)
                    Text("أضف حسابك الأول للبدء", color = SecondaryText, style = MaterialTheme.typography.bodySmall)
                }
            }
        } else {
            LazyColumn(modifier = Modifier.padding(padding).fillMaxSize().background(Black), contentPadding = PaddingValues(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(uiState.accounts, key = { it.account.id }) { item ->
                    Card(colors = CardDefaults.cardColors(containerColor = LightGray), modifier = Modifier.fillMaxWidth()) {
                        Row(modifier = Modifier.padding(16.dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                            Column {
                                Text(item.account.name, color = White, style = MaterialTheme.typography.titleMedium)
                                Text("الافتتاحي: ${item.account.openingBalance} | الحالي: ${String.format("%.2f", item.currentBalance)}", color = if (item.currentBalance >= 0) GreenAccent else RedAccent)
                            }
                            Row {
                                IconButton(onClick = { editAcc = item; name = item.account.name; opening = item.account.openingBalance.toString(); showDialog = true }) { Icon(Icons.Default.Edit, null, tint = White) }
                                IconButton(onClick = { vm.delete(item.account) }) { Icon(Icons.Default.Delete, null, tint = RedAccent) }
                            }
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
                        OutlinedTextField(
                            value = name, 
                            onValueChange = { name = it }, 
                            label = { Text("الاسم *") }, 
                            isError = name.isBlank(),
                            supportingText = if (name.isBlank()) { { Text("الاسم مطلوب", color = RedAccent) } } else null
                        )
                        Spacer(Modifier.height(8.dp))
                        OutlinedTextField(
                            value = opening, 
                            onValueChange = { opening = it }, 
                            label = { Text("الرصيد الافتتاحي") },
                            isError = opening.isNotEmpty() && opening.toDoubleOrNull() == null,
                            supportingText = if (opening.isNotEmpty() && opening.toDoubleOrNull() == null) { { Text("رقم غير صالح", color = RedAccent) } } else null
                        )
                    }
                },
                confirmButton = { 
                    TextButton(onClick = { 
                        if (editAcc == null) vm.add(name, opening) else vm.update(editAcc!!.account.copy(name = name, openingBalance = opening.toDoubleOrNull() ?: 0.0))
                        showDialog = false 
                    }, enabled = name.isNotBlank() && (opening.isEmpty() || opening.toDoubleOrNull() != null)) { Text("حفظ") } 
                },
                dismissButton = { TextButton(onClick = { showDialog = false }) { Text("إلغاء") } }
            )
        }
    }
}
