package com.transferslog.app.ui.screens

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import com.transferslog.app.ui.theme.*
import com.transferslog.app.viewmodel.MainViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(vm: MainViewModel, nav: NavController) {
    val ctx = LocalContext.current
    val settings = vm.settings

    var currency by remember { mutableStateOf(settings.currency) }
    var commission1 by remember { mutableStateOf(settings.commission1.toString()) }
    var commission2 by remember { mutableStateOf(settings.commission2.toString()) }
    var defaultIsFirst by remember { mutableStateOf(settings.defaultCommissionIsFirst) }

    var showClearDialog by remember { mutableStateOf(false) }
    var showAboutDialog by remember { mutableStateOf(false) }

    val exportLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/json")
    ) { uri ->
        if (uri != null) {
            vm.exportBackup { json ->
                if (json != null) {
                    try {
                        ctx.contentResolver.openOutputStream(uri)?.use {
                            it.write(json.toByteArray(Charsets.UTF_8))
                        }
                        Toast.makeText(ctx, "✅ تم تصدير النسخة الاحتياطية", Toast.LENGTH_SHORT).show()
                    } catch (e: Exception) {
                        Toast.makeText(ctx, "فشل التصدير", Toast.LENGTH_SHORT).show()
                    }
                }
            }
        }
    }

    val importLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) {
            try {
                val json = ctx.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
                if (json != null) {
                    vm.importBackup(json) { ok ->
                        Toast.makeText(
                            ctx,
                            if (ok) "✅ تم استيراد البيانات" else "❌ ملف غير صالح",
                            Toast.LENGTH_SHORT
                        ).show()
                    }
                }
            } catch (e: Exception) {
                Toast.makeText(ctx, "فشل القراءة", Toast.LENGTH_SHORT).show()
            }
        }
    }

    Scaffold(
        containerColor = BlackBg,
        topBar = {
            TopAppBar(
                title = { Text("الإعدادات", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = { nav.popBackStack() }) {
                        Icon(Icons.Default.ArrowBack, "رجوع", tint = WhiteText)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = DarkSurface,
                    titleContentColor = WhiteText
                )
            )
        }
    ) { padding ->
        Column(
            Modifier.padding(padding).fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)
        ) {
            SectionTitle("العملة", Icons.Default.AttachMoney)
            OutlinedTextField(
                value = currency,
                onValueChange = { currency = it; settings.currency = it },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = GreenBright,
                    unfocusedBorderColor = DividerGray,
                    focusedTextColor = WhiteText,
                    unfocusedTextColor = WhiteText,
                    focusedContainerColor = DarkCard,
                    unfocusedContainerColor = DarkCard,
                    cursorColor = GreenBright
                )
            )

            Spacer(Modifier.height(20.dp))

            SectionTitle("قيم العمولة", Icons.Default.Payments)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = commission1,
                    onValueChange = {
                        commission1 = it.filter { c -> c.isDigit() || c == '.' }
                        commission1.toDoubleOrNull()?.let { v -> settings.commission1 = v }
                    },
                    label = { Text("العمولة الأولى") },
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = GreenBright,
                        unfocusedBorderColor = DividerGray,
                        focusedTextColor = WhiteText,
                        unfocusedTextColor = WhiteText,
                        focusedContainerColor = DarkCard,
                        unfocusedContainerColor = DarkCard,
                        cursorColor = GreenBright
                    )
                )
                OutlinedTextField(
                    value = commission2,
                    onValueChange = {
                        commission2 = it.filter { c -> c.isDigit() || c == '.' }
                        commission2.toDoubleOrNull()?.let { v -> settings.commission2 = v }
                    },
                    label = { Text("العمولة الثانية") },
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = GreenBright,
                        unfocusedBorderColor = DividerGray,
                        focusedTextColor = WhiteText,
                        unfocusedTextColor = WhiteText,
                        focusedContainerColor = DarkCard,
                        unfocusedContainerColor = DarkCard,
                        cursorColor = GreenBright
                    )
                )
            }

            Spacer(Modifier.height(12.dp))
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(Modifier.weight(1f)) {
                    Text("العمولة الافتراضية", color = WhiteText, fontWeight = FontWeight.Bold)
                    Text(
                        "المُحدَّدة تلقائياً عند إضافة حوالة مدفوعة",
                        color = GrayText, fontSize = 11.sp
                    )
                }
                Switch(
                    checked = defaultIsFirst,
                    onCheckedChange = { defaultIsFirst = it; settings.defaultCommissionIsFirst = it },
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = BlackBg,
                        checkedTrackColor = GreenBright,
                        uncheckedThumbColor = GrayText,
                        uncheckedTrackColor = DarkCard
                    )
                )
            }

            Spacer(Modifier.height(24.dp))

            SectionTitle("النسخ الاحتياطي", Icons.Default.Backup)
            Text(
                "احفظ بياناتك في ملف JSON للاحتفاظ بها أو نقلها لجهاز آخر",
                color = GrayText, fontSize = 12.sp
            )
            Spacer(Modifier.height(10.dp))
            SettingsButton(
                icon = Icons.Default.FileDownload,
                label = "تصدير نسخة احتياطية",
                color = GreenReceived,
                onClick = {
                    val fname = "transfers_backup_${System.currentTimeMillis()}.json"
                    exportLauncher.launch(fname)
                }
            )
            Spacer(Modifier.height(8.dp))
            SettingsButton(
                icon = Icons.Default.FileUpload,
                label = "استيراد من ملف",
                color = GoldProfit,
                onClick = { importLauncher.launch(arrayOf("application/json", "*/*")) }
            )

            Spacer(Modifier.height(24.dp))

            SectionTitle("البيانات", Icons.Default.Storage)
            SettingsButton(
                icon = Icons.Default.DeleteForever,
                label = "حذف كل البيانات",
                color = RedPaid,
                onClick = { showClearDialog = true }
            )

            Spacer(Modifier.height(24.dp))

            SectionTitle("عن البرنامج", Icons.Default.Info)
            SettingsButton(
                icon = Icons.Default.Info,
                label = "معلومات التطبيق",
                color = GreenBright,
                onClick = { showAboutDialog = true }
            )

            Spacer(Modifier.height(32.dp))

            Text(
                "صُنع بحب 💚",
                color = GrayText, fontSize = 12.sp,
                modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center
            )
            Text(
                "المبرمج: أدهم الهبة",
                color = GreenBright, fontSize = 13.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(16.dp))
        }
    }

    if (showClearDialog) {
        AlertDialog(
            onDismissRequest = { showClearDialog = false },
            containerColor = DarkCard,
            title = { Text("⚠️ حذف كل البيانات", color = RedBright) },
            text = {
                Text(
                    "سيتم حذف جميع الحوالات والحسابات والأسماء المحفوظة نهائياً. لا يمكن التراجع!",
                    color = GrayText
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    vm.clearAll()
                    showClearDialog = false
                    Toast.makeText(ctx, "🗑️ تم حذف كل البيانات", Toast.LENGTH_SHORT).show()
                }) { Text("حذف نهائي", color = RedBright, fontWeight = FontWeight.Bold) }
            },
            dismissButton = {
                TextButton(onClick = { showClearDialog = false }) { Text("إلغاء", color = GrayText) }
            }
        )
    }

    if (showAboutDialog) {
        AlertDialog(
            onDismissRequest = { showAboutDialog = false },
            containerColor = DarkCard,
            icon = { Icon(Icons.Default.AccountBalanceWallet, null, tint = GreenBright, modifier = Modifier.size(48.dp)) },
            title = { Text("سجل الحوالات", color = WhiteText, fontWeight = FontWeight.Bold) },
            text = {
                Column {
                    AboutRow("الإصدار", "1.0")
                    AboutRow("المبرمج", "أدهم الهبة")
                    AboutRow("الحزمة", "com.transferslog.app")
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "تطبيق لإدارة الحوالات المالية يعمل دون اتصال بالإنترنت، مع دعم كامل للغة العربية وتخزين آمن للبيانات.",
                        color = GrayText, fontSize = 12.sp
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = { showAboutDialog = false }) {
                    Text("حسناً", color = GreenBright)
                }
            }
        )
    }
}

@Composable
fun SectionTitle(title: String, icon: androidx.compose.ui.graphics.vector.ImageVector) {
    Row(
        Modifier.fillMaxWidth().padding(bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(icon, null, tint = GreenBright, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(8.dp))
        Text(title, color = WhiteText, fontWeight = FontWeight.Bold, fontSize = 16.sp)
    }
}

@Composable
fun SettingsButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    color: Color,
    onClick: () -> Unit
) {
    OutlinedButton(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().height(50.dp),
        shape = RoundedCornerShape(12.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, color.copy(alpha = 0.5f))
    ) {
        Icon(icon, null, tint = color, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(10.dp))
        Text(label, color = color, fontWeight = FontWeight.Bold)
    }
}

@Composable
fun AboutRow(label: String, value: String) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(label, color = GrayText, fontSize = 13.sp)
        Text(value, color = WhiteText, fontSize = 13.sp, fontWeight = FontWeight.Bold)
    }
}
