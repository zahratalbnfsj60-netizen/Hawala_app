package com.transferslog.app.ui.components

import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.transferslog.app.data.Transfer
import com.transferslog.app.data.TransferType
import com.transferslog.app.ui.theme.*
import java.text.DecimalFormat
import java.text.SimpleDateFormat
import java.util.*

@Composable
fun TransferCard(transfer: Transfer, onClick: () -> Unit) {
    val borderColor = if (transfer.type == TransferType.RECEIVED) GreenAccent else RedAccent
    val format = DecimalFormat("#,###.##")
    Card(modifier = Modifier.fillMaxWidth().border(1.dp, borderColor, RoundedCornerShape(8.dp)).clickable { onClick() }, shape = RoundedCornerShape(8.dp), colors = CardDefaults.cardColors(containerColor = LightGray)) {
        Row(modifier = Modifier.padding(16.dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            Column {
                Text(transfer.recipientName, color = White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Text(SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date(transfer.date)), color = SecondaryText, fontSize = 12.sp)
            }
            Column(horizontalAlignment = Alignment.End) {
                Text("${format.format(transfer.amount)} ل.س", color = borderColor, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                if (transfer.type == TransferType.PAID && transfer.paidNumber != null) Text("رقم: ${transfer.paidNumber}", color = SecondaryText, fontSize = 12.sp)
            }
        }
    }
}
