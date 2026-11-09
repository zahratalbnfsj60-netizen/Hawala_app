package com.transferslog.app.ui.screens

import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.transferslog.app.ui.MainViewModel
import com.transferslog.app.ui.theme.*
import com.transferslog.app.util.*
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(vm: MainViewModel, onBack: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val snackbar = remember { SnackbarHostState() }
    LaunchedEffect(Unit) { AppPrefs.init(ctx) }

    var currency by remember { mutableStateOf(AppPrefs.currencyState.value) }
    var c1 by remember { mutableStateOf(AppPrefs.comm1State.value.toString()) }
    var c2 by remember { mutableStateOf(AppPrefs.comm2State.value.toString()) }

    var showWipe1 by remember { mutableStateOf(false) }
    var showWipe2 by remember { mutableStateOf(false) }
    var showPdfRange by remember { mutableStateOf(false) }
    var pdfFrom by remember { mutableStateOf(toStartOfDay(System.currentTimeMillis() - 30L*86400000)) }
    var pdfTo by remember { mutableStateOf(toEndOfDay(System.currentTimeMillis())) }
    var showFromPicker by remember { mutableStateOf(false) }
    var showToPicker by remember { mutableStateOf(false) }

    val selectedId by vm.selectedId.collectAsStateWithLifecycle()

    val exportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        uri?.let { scope.launch { try { BackupHelper.export(ctx, it); snackbar.showSnackbar("تم التصدير") } catch (e: Exception) { snackbar.showSnackbar("فشل التصدير: ${e.message}") } } }
    }
    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri?.let { scope.launch { try { BackupHelper.import(ctx, it); snackbar.showSnackbar("تم الاستيراد") } catch (e: Exception) { snackbar.showSnackbar("فشل الاستيراد: ${e.message}") } } }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) }, containerColor = Black,
        topBar = {
            TopAppBar(colors = TopAppBarDefaults.topAppBarColors(containerColor = Black), title = { Text("الإعدادات", color = White) }, navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowForward, null, tint = White) } })
        }
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(CardDark).padding(14.dp)) {
                Text("العملة", color = GreenBright, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(value = currency, onValueChange = { currency = it }, singleLine = true, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedContainerColor = CardDark2, unfocusedContainerColor = CardDark2, focusedTextColor = White, unfocusedTextColor = White, focusedBorderColor = GreenBright, unfocusedBorderColor = CardDark2, cursorColor = GreenBright))
                Spacer(Modifier.height(8.dp))
                Button(onClick = { AppPrefs.setCurrency(ctx, currency.trim().ifEmpty { "ل.س" }); scope.launch { snackbar.showSnackbar("تم الحفظ") } }, colors = ButtonDefaults.buttonColors(containerColor = GreenBright)) { Text("حفظ", color = Black) }
            }

            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(CardDark).padding(14.dp)) {
                Text("قيم العمولات السريعة", color = GreenBright, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(value = c1, onValueChange = { c1 = it.filter { ch -> ch.isDigit() } }, label = { Text("الأولى") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true, modifier = Modifier.weight(1f), colors = OutlinedTextFieldDefaults.colors(focusedContainerColor = CardDark2, unfocusedContainerColor = CardDark2, focusedTextColor = White, unfocusedTextColor = White, focusedBorderColor = GreenBright, unfocusedBorderColor = CardDark2, cursorColor = GreenBright))
                    OutlinedTextField(value = c2, onValueChange = { c2 = it.filter { ch -> ch.isDigit() } }, label = { Text("الثانية") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true, modifier = Modifier.weight(1f), colors = OutlinedTextFieldDefaults.colors(focusedContainerColor = CardDark2, unfocusedContainerColor = CardDark2, focusedTextColor = White, unfocusedTextColor = White, focusedBorderColor = GreenBright, unfocusedBorderColor = CardDark2, cursorColor = GreenBright))
                }
                Spacer(Modifier.height(8.dp))
                Button(onClick = { AppPrefs.setComm1(ctx, c1.toIntOrNull() ?: 100); AppPrefs.setComm2(ctx, c2.toIntOrNull() ?: 250); scope.launch { snackbar.showSnackbar("تم الحفظ") } }, colors = ButtonDefaults.buttonColors(containerColor = GreenBright)) { Text("حفظ", color = Black) }
            }

            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(CardDark).padding(14.dp)) {
                Text("النسخ الاحتياطي", color = GreenBright, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(Modifier.height(8.dp))
                MenuRow(Icons.Default.Upload, "تصدير JSON") { exportLauncher.launch("hawala_backup_${System.currentTimeMillis()}.json") }
                MenuRow(Icons.Default.Download, "استيراد JSON") { importLauncher.launch(arrayOf("application/json")) }
            }

            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(CardDark).padding(14.dp)) {
                Text("تصدير PDF", color = GreenBright, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(Modifier.height(8.dp))
                MenuRow(Icons.Default.PictureAsPdf, "توليد كشف حساب PDF") { showPdfRange = true }
            }

            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(CardDark).padding(14.dp)) {
                Text("منطقة الخطر", color = GreenBright, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(Modifier.height(8.dp))
                MenuRow(Icons.Default.DeleteForever, "حذف كل البيانات", RedBright) { showWipe1 = true }
            }

            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(CardDark).padding(14.dp)) {
                Text("عن البرنامج", color = GreenBright, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(Modifier.height(8.dp))
                Row(Modifier.fillMaxWidth().padding(vertical = 4.dp)) { Text("الإصدار", color = GrayText, modifier = Modifier.weight(1f), fontSize = 14.sp); Text("2.0", color = White, fontSize = 14.sp) }
                Row(Modifier.fillMaxWidth().padding(vertical = 4.dp)) { Text("المبرمج", color = GrayText, modifier = Modifier.weight(1f), fontSize = 14.sp); Text("أدهم الهبة", color = White, fontSize = 14.sp) }
            }
        }
    }

    if (showWipe1) AlertDialog(onDismissRequest = { showWipe1 = false }, containerColor = CardDark, title = { Text("حذف كل البيانات", color = White) }, text = { Text("سيتم حذف جميع الحسابات والحوالات والأسماء المحفوظة. لا يمكن التراجع. متابعة؟", color = GrayText) }, confirmButton = { TextButton(onClick = { showWipe1 = false; showWipe2 = true }) { Text("متابعة", color = RedBright) } }, dismissButton = { TextButton(onClick = { showWipe1 = false }) { Text("إلغاء", color = GrayText) } })
    if (showWipe2) AlertDialog(onDismissRequest = { showWipe2 = false }, containerColor = CardDark, title = { Text("تأكيد نهائي", color = White) }, text = { Text("هل أنت متأكد 100%؟ هذا الإجراء لا يمكن التراجع عنه.", color = GrayText) }, confirmButton = { TextButton(onClick = { showWipe2 = false; scope.launch { try { vm.wipeAll(); snackbar.showSnackbar("تم الحذف") } catch (e: Exception) { snackbar.showSnackbar("فشل: ${e.message}") } } }) { Text("حذف نهائي", color = RedBright) } }, dismissButton = { TextButton(onClick = { showWipe2 = false }) { Text("إلغاء", color = GrayText) } })

    if (showPdfRange) {
        val accId = selectedId
        AlertDialog(
            onDismissRequest = { showPdfRange = false }, containerColor = CardDark, title = { Text("فترة الكشف", color = White) },
            text = { Column { OutlinedButton(onClick = { showFromPicker = true }, modifier = Modifier.fillMaxWidth()) { Text("من: ${formatDate(pdfFrom)}", color = White) }; Spacer(Modifier.height(8.dp)); OutlinedButton(onClick = { showToPicker = true }, modifier = Modifier.fillMaxWidth()) { Text("إلى: ${formatDate(pdfTo)}", color = White) } } },
            confirmButton = {
                TextButton(onClick = {
                    if (accId == null) { scope.launch { snackbar.showSnackbar("اختر حساباً أولاً") }; return@TextButton }
                    scope.launch {
                        try {
                            val acc = vm.selectedAccount.value ?: return@launch
                            val list = vm.transfersInRange(accId, pdfFrom, pdfTo)
                            val file = PdfExporter.export(ctx, acc, list, pdfFrom, pdfTo, AppPrefs.currencyState.value)
                            val uri = FileProvider.getUriForFile(ctx, "${ctx.packageName}.fileprovider", file)
                            val intent = Intent(Intent.ACTION_SEND).apply { type = "application/pdf"; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION) }
                            ctx.startActivity(Intent.createChooser(intent, "مشاركة الكشف"))
                            showPdfRange = false
                        } catch (e: Exception) { snackbar.showSnackbar("فشل: ${e.message}") }
                    }
                }) { Text("تصدير", color = GreenBright) }
            },
            dismissButton = { TextButton(onClick = { showPdfRange = false }) { Text("إلغاء", color = GrayText) } }
        )
    }
    if (showFromPicker) { val st = rememberDatePickerState(initialSelectedDateMillis = pdfFrom); DatePickerDialog(onDismissRequest = { showFromPicker = false }, confirmButton = { TextButton(onClick = { st.selectedDateMillis?.let { pdfFrom = toStartOfDay(it) }; showFromPicker = false }) { Text("موافق", color = GreenBright) } }, dismissButton = { TextButton(onClick = { showFromPicker = false }) { Text("إلغاء", color = GrayText) } }) { DatePicker(state = st) } }
    if (showToPicker) { val st = rememberDatePickerState(initialSelectedDateMillis = pdfTo); DatePickerDialog(onDismissRequest = { showToPicker = false }, confirmButton = { TextButton(onClick = { st.selectedDateMillis?.let { pdfTo = toEndOfDay(it) }; showToPicker = false }) { Text("موافق", color = GreenBright) } }, dismissButton = { TextButton(onClick = { showToPicker = false }) { Text("إلغاء", color = GrayText) } }) { DatePicker(state = st) } }
}

@Composable
private fun MenuRow(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, color: Color = White, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)).clickable { onClick() }.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = color)
        Spacer(Modifier.width(12.dp))
        Text(label, color = color, fontSize = 15.sp)
    }
}
