package com.transferslog.app.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import com.transferslog.app.data.TransferType
import com.transferslog.app.viewmodel.MainViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen(vm: MainViewModel, nav: NavController) {
    val accounts by vm.accounts.collectAsState()
    val transfers by vm.transfers.collectAsState()
    var selectedAccount by remember { mutableStateOf<Int?>(null) }
    var expanded by remember { mutableStateOf(false) }

    val filtered = if (selectedAccount == null) transfers else transfers.filter { it.accountId == selectedAccount }

    val received = filtered.filter { it.type == TransferType.RECEIVED }.sumOf { it.amount }
    val paid = filtered.filter { it.type == TransferType.PAID }.sumOf { it.amount }
    val commission = filtered.filter { it.type == TransferType.PAID }.sumOf { it.commission }
    val opening = if (selectedAccount == null) {
        accounts.sumOf { it.openingBalance }
    } else {
        accounts.firstOrNull { it.id == selectedAccount }?.openingBalance ?: 0.0
    }
    val remaining = opening + received - paid - commission

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("الإحصائيات") },
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
        }
    ) { padding ->
        Column(
            Modifier.padding(padding).padding(16.dp).fillMaxSize().verticalScroll(rememberScrollState())
        ) {
            ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
                OutlinedTextField(
                    value = selectedAccount?.let { id -> accounts.firstOrNull { it.id == id }?.name } ?: "كل الحسابات",
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("الحساب") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
                    modifier = Modifier.menuAnchor().fillMaxWidth()
                )
                ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                    DropdownMenuItem(
                        text = { Text("كل الحسابات") },
                        onClick = { selectedAccount = null; expanded = false }
                    )
                    accounts.forEach { acc ->
                        DropdownMenuItem(
                            text = { Text(acc.name) },
                            onClick = { selectedAccount = acc.id; expanded = false }
                        )
                    }
                }
            }

            Spacer(Modifier.height(16.dp))
            StatCard("الرصيد الافتتاحي", opening, MaterialTheme.colorScheme.secondary)
            StatCard("إجمالي المستلم", received, MaterialTheme.colorScheme.primary)
            StatCard("إجمالي المدفوع", paid, MaterialTheme.colorScheme.error)
            StatCard("إجمالي العمولات (الربح)", commission, MaterialTheme.colorScheme.tertiary)
            StatCard("الباقي", remaining, if (remaining >= 0) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error)
        }
    }
}

@Composable
fun StatCard(label: String, value: Double, color: Color) {
    Card(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        colors = CardDefaults.cardColors(containerColor = color.copy(alpha = 0.1f))
    ) {
        Row(
            Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(label, fontWeight = FontWeight.Bold)
            Text("$value ل.س", fontWeight = FontWeight.Bold, color = color)
        }
    }
}
