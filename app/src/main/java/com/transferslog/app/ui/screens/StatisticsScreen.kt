package com.transferslog.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.transferslog.app.ui.theme.*
import com.transferslog.app.ui.viewmodel.StatisticsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StatisticsScreen(vm: StatisticsViewModel, onBack: () -> Unit) {
    val stats by vm.stats.collectAsState()
    Scaffold(
        topBar = { TopAppBar(title = { Text("الإحصائيات") }, navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, null) } }, colors = TopAppBarDefaults.topAppBarColors(containerColor = Black, titleContentColor = White, navigationIconContentColor = White)) }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize().background(Black).padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            StatRow("الرصيد الافتتاحي", stats.openingBalance, White)
            StatRow("إجمالي المستلم", stats.totalReceived, GreenAccent)
            StatRow("إجمالي المدفوع", stats.totalPaid, RedAccent)
            StatRow("العمولات (الربح)", stats.totalCommission, GreenAccent)
            Divider(color = LightGray)
            StatRow("الباقي", stats.remaining, White)
        }
    }
}

@Composable
fun StatRow(label: String, value: Double, color: androidx.compose.ui.graphics.Color) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, color = SecondaryText, fontSize = 18.sp)
        Text(String.format("%.2f", value), color = color, fontSize = 18.sp)
    }
}
