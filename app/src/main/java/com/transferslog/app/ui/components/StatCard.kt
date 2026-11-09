package com.transferslog.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.transferslog.app.ui.theme.CardDark
import com.transferslog.app.ui.theme.GrayText

@Composable
fun StatCard(title: String, value: String, valueColor: Color = Color.White, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.clip(RoundedCornerShape(12.dp)).background(CardDark).padding(10.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(title, color = GrayText, fontSize = 11.sp)
        Spacer(Modifier.height(4.dp))
        Text(value, color = valueColor, fontSize = 14.sp, fontWeight = FontWeight.Bold)
    }
}
