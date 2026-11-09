package com.transferslog.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.transferslog.app.ui.theme.*

@Composable
fun StatBar(opening: Double, paid: Double, received: Double) {
    Row(modifier = Modifier.fillMaxWidth().background(DarkGray).padding(8.dp), horizontalArrangement = Arrangement.SpaceEvenly) {
        StatItem("افتتاحي", opening, White)
        StatItem("مدفوع", paid, RedAccent)
        StatItem("مستلم", received, GreenAccent)
    }
}

@Composable
private fun StatItem(label: String, value: Double, color: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, color = SecondaryText, fontSize = 10.sp)
        Text(String.format("%.0f", value), color = color, fontWeight = FontWeight.Bold, fontSize = 14.sp)
    }
}
