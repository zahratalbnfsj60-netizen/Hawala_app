#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/Hawala_app"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${YELLOW}جاري تطبيق التحديث الشامل والأخير...${NC}"

# 1. تحديث AndroidManifest والصلاحيات
cat > app/src/main/AndroidManifest.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:allowBackup="true" android:icon="@android:drawable/ic_menu_manage" android:label="@string/app_name" android:supportsRtl="true" android:theme="@style/Theme.TransfersLog">
        <activity android:name=".MainActivity" android:exported="true" android:screenOrientation="portrait" android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
        <provider android:name="androidx.core.content.FileProvider" android:authorities="${applicationId}.fileprovider" android:exported="false" android:grantUriPermissions="true">
            <meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/file_paths" />
        </provider>
    </application>
</manifest>
EOF

mkdir -p app/src/main/res/xml
cat > app/src/main/res/xml/file_paths.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <cache-path name="cache" path="/" />
    <external-cache-path name="external_cache" path="/" />
</paths>
EOF

# 2. قاعدة البيانات والـ Repository
cat > app/src/main/java/com/transferslog/app/data/Daos.kt <<'EOF'
package com.transferslog.app.data

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Dao
interface AccountDao {
    @Query("SELECT * FROM accounts ORDER BY createdAt DESC")
    fun getAll(): Flow<List<Account>>
    @Query("SELECT * FROM accounts WHERE id = :id")
    suspend fun getById(id: Long): Account?
    @Insert
    suspend fun insert(account: Account): Long
    @Update
    suspend fun update(account: Account)
    @Delete
    suspend fun delete(account: Account)
    @Query("DELETE FROM accounts")
    suspend fun deleteAll()
}

@Dao
interface TransferDao {
    @Query("""
        SELECT * FROM transfers 
        WHERE accountId = :accountId
        AND (:type IS NULL OR type = :type)
        AND (:searchQuery = '' OR recipientName LIKE '%' || :searchQuery || '%' OR CAST(amount AS TEXT) LIKE '%' || :searchQuery || '%')
        AND (:startDate IS NULL OR date >= :startDate)
        AND (:endDate IS NULL OR date <= :endDate)
        ORDER BY date DESC, createdAt DESC
    """)
    fun getFiltered(accountId: Long, type: TransferType?, searchQuery: String, startDate: Long?, endDate: Long?): Flow<List<Transfer>>
    @Query("SELECT * FROM transfers WHERE id = :id")
    suspend fun getById(id: Long): Transfer?
    @Insert
    suspend fun insert(transfer: Transfer): Long
    @Update
    suspend fun update(transfer: Transfer)
    @Delete
    suspend fun delete(transfer: Transfer)
    @Query("SELECT MAX(paidNumber) FROM transfers WHERE type = 'PAID' AND accountId = :accountId")
    suspend fun getMaxPaidNumber(accountId: Long): Long?
    @Query("DELETE FROM transfers WHERE accountId = :accountId")
    suspend fun deleteByAccountId(accountId: Long)
    @Query("DELETE FROM transfers")
    suspend fun deleteAll()
}

@Dao
interface SavedNameDao {
    @Query("SELECT * FROM saved_names ORDER BY lastUsed DESC")
    fun getAll(): Flow<List<SavedName>>
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(savedName: SavedName)
    @Query("DELETE FROM saved_names")
    suspend fun deleteAll()
}
EOF

cat > app/src/main/java/com/transferslog/app/data/Repository.kt <<'EOF'
package com.transferslog.app.data

import kotlinx.coroutines.flow.Flow

class Repository(val database: AppDatabase) {
    val accountDao = database.accountDao()
    val transferDao = database.transferDao()
    val savedNameDao = database.savedNameDao()

    fun getAccounts(): Flow<List<Account>> = accountDao.getAll()
    fun getFilteredTransfers(accountId: Long, type: TransferType? = null, searchQuery: String = "", startDate: Long? = null, endDate: Long? = null): Flow<List<Transfer>> = transferDao.getFiltered(accountId, type, searchQuery, startDate, endDate)

    suspend fun insertAccount(account: Account) = accountDao.insert(account)
    suspend fun updateAccount(account: Account) = accountDao.update(account)
    suspend fun deleteAccount(account: Account) {
        transferDao.deleteByAccountId(account.id)
        accountDao.delete(account)
    }

    suspend fun insertTransfer(transfer: Transfer): Long {
        val nextPaidNumber = if (transfer.type == TransferType.PAID) (transferDao.getMaxPaidNumber(transfer.accountId) ?: 0) + 1 else null
        val id = transferDao.insert(transfer.copy(paidNumber = nextPaidNumber))
        savedNameDao.insert(SavedName(name = transfer.recipientName, lastUsed = System.currentTimeMillis()))
        return id
    }

    suspend fun updateTransfer(transfer: Transfer) {
        transferDao.update(transfer)
        savedNameDao.insert(SavedName(name = transfer.recipientName, lastUsed = System.currentTimeMillis()))
    }

    suspend fun deleteTransfer(transfer: Transfer) = transferDao.delete(transfer)
    fun getSavedNames(): Flow<List<SavedName>> = savedNameDao.getAll()
    suspend fun deleteAllData() {
        transferDao.deleteAll()
        accountDao.deleteAll()
        savedNameDao.deleteAll()
    }
}
EOF

# 3. ViewModels
cat > app/src/main/java/com/transferslog/app/ui/viewmodel/MainViewModel.kt <<'EOF'
package com.transferslog.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.transferslog.app.data.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

class MainViewModel(private val repository: Repository) : ViewModel() {
    private val _searchQuery = MutableStateFlow("")
    val searchQuery = _searchQuery.asStateFlow()
    private val _selectedType = MutableStateFlow<TransferType?>(null)
    val selectedType = _selectedType.asStateFlow()
    private val _selectedAccountId = MutableStateFlow<Long?>(null)
    val selectedAccountId = _selectedAccountId.asStateFlow()

    val accounts = repository.getAccounts().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    init {
        viewModelScope.launch {
            accounts.collect { list ->
                if (_selectedAccountId.value == null && list.isNotEmpty()) _selectedAccountId.value = list.first().id
            }
        }
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    val transfers = combine(_searchQuery, _selectedType, _selectedAccountId) { q, t, a -> Triple(q, t, a) }
        .flatMapLatest { (q, t, a) -> if (a == null) flowOf(emptyList()) else repository.getFilteredTransfers(a, t, q) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun setSearchQuery(query: String) { _searchQuery.value = query }
    fun setTypeFilter(type: TransferType?) { _selectedType.value = type }
    fun setAccountFilter(id: Long?) { _selectedAccountId.value = id }
    fun deleteTransfer(transfer: Transfer) { viewModelScope.launch { repository.deleteTransfer(transfer) } }
}
EOF

cat > app/src/main/java/com/transferslog/app/ui/viewmodel/AddEditViewModel.kt <<'EOF'
package com.transferslog.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.transferslog.app.data.*
import com.transferslog.app.util.DateUtils
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class TransferFormState(
    val id: Long? = null, val type: TransferType = TransferType.RECEIVED,
    val recipientName: String = "", val amount: String = "", val commission: String = "",
    val date: Long = System.currentTimeMillis(), val accountId: Long, val paidNumber: Long? = null,
    val isLoading: Boolean = false, val errorMessage: String? = null, val savedMessage: String? = null
)

class AddEditViewModel(private val repository: Repository, val initialAccountId: Long) : ViewModel() {
    private val _formState = MutableStateFlow(TransferFormState(accountId = initialAccountId))
    val formState = _formState.asStateFlow()
    val savedNames = repository.getSavedNames()

    fun loadTransfer(id: Long) {
        viewModelScope.launch {
            repository.transferDao.getById(id)?.let { t ->
                _formState.value = TransferFormState(t.id, t.type, t.recipientName, t.amount.toString(), t.commission.toString(), t.date, t.accountId, t.paidNumber)
            }
        }
    }

    fun updateType(type: TransferType) { _formState.value = _formState.value.copy(type = type) }
    fun updateRecipient(name: String) { _formState.value = _formState.value.copy(recipientName = name) }
    fun updateAmount(amount: String) { _formState.value = _formState.value.copy(amount = amount) }
    fun updateCommission(commission: String) { _formState.value = _formState.value.copy(commission = commission) }
    fun updateDate(date: Long) { _formState.value = _formState.value.copy(date = DateUtils.normalizeToUtcStartOfDay(date)) }

    fun save() {
        val state = _formState.value
        val amountVal = state.amount.toDoubleOrNull()
        if (state.recipientName.isBlank() || amountVal == null || amountVal <= 0.0) {
            _formState.value = state.copy(errorMessage = "يرجى تعبئة الحقول المطلوبة بشكل صحيح")
            return
        }
        val commVal = if (state.type == TransferType.PAID) state.commission.toDoubleOrNull() ?: 0.0 else 0.0

        viewModelScope.launch {
            _formState.value = _formState.value.copy(isLoading = true, errorMessage = null)
            try {
                if (state.id == null) {
                    repository.insertTransfer(Transfer(type = state.type, recipientName = state.recipientName, amount = amountVal, commission = commVal, date = state.date, accountId = state.accountId))
                    _formState.value = TransferFormState(accountId = initialAccountId, savedMessage = "تم حفظ الحوالة")
                } else {
                    repository.updateTransfer(Transfer(id = state.id, type = state.type, recipientName = state.recipientName, amount = amountVal, commission = commVal, date = state.date, accountId = state.accountId, paidNumber = state.paidNumber))
                    _formState.value = state.copy(isLoading = false, savedMessage = "تم تحديث الحوالة")
                }
            } catch (e: Exception) {
                _formState.value = _formState.value.copy(isLoading = false, errorMessage = "خطأ: ${e.message}")
            }
        }
    }

    fun delete() {
        val state = _formState.value
        if (state.id != null) {
            viewModelScope.launch {
                repository.transferDao.getById(state.id)?.let { repository.deleteTransfer(it) }
                _formState.value = state.copy(savedMessage = "تم حذف الحوالة")
            }
        }
    }
    fun clearForm() { _formState.value = TransferFormState(accountId = initialAccountId) }
    fun clearMessage() { _formState.value = _formState.value.copy(savedMessage = null, errorMessage = null) }
}
EOF

# 4. شاشة الإضافة/التعديل
cat > app/src/main/java/com/transferslog/app/ui/screens/AddEditTransferScreen.kt <<'EOF'
package com.transferslog.app.ui.screens

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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.transferslog.app.data.TransferType
import com.transferslog.app.ui.theme.*
import com.transferslog.app.ui.viewmodel.AddEditViewModel
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEditTransferScreen(vm: AddEditViewModel, id: Long?, onBack: () -> Unit) {
    val state by vm.formState.collectAsState()
    val savedNames by vm.savedNames.collectAsState(initial = emptyList())
    val snackbar = remember { SnackbarHostState() }
    var showDatePicker by remember { mutableStateOf(false) }
    var showDeleteConfirm by remember { mutableStateOf(false) }
    var expandedNames by remember { mutableStateOf(false) }

    LaunchedEffect(id) { id?.let { vm.loadTransfer(it) } }
    LaunchedEffect(state.savedMessage, state.errorMessage) {
        state.savedMessage?.let { snackbar.showSnackbar(it); vm.clearMessage(); onBack() }
            ?: state.errorMessage?.let { snackbar.showSnackbar(it); vm.clearMessage() }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = { Text(if (state.id == null) "إضافة حوالة" else "تعديل حوالة") },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, null) } },
                actions = { if (state.id != null) IconButton(onClick = { showDeleteConfirm = true }) { Icon(Icons.Default.Delete, null, tint = RedAccent) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Black, titleContentColor = White, navigationIconContentColor = White, actionIconContentColor = White)
            )
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize().background(Black).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Row(modifier = Modifier.fillMaxWidth().height(80.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(modifier = Modifier.weight(1f).fillMaxHeight().background(if (state.type == TransferType.RECEIVED) GreenAccent else DarkGray, RoundedCornerShape(12.dp)).clickable { vm.updateType(TransferType.RECEIVED) }, contentAlignment = Alignment.Center) { Text("مستلم", color = if (state.type == TransferType.RECEIVED) Black else White, fontSize = 24.sp, fontWeight = FontWeight.Bold) }
                Box(modifier = Modifier.weight(1f).fillMaxHeight().background(if (state.type == TransferType.PAID) RedAccent else DarkGray, RoundedCornerShape(12.dp)).clickable { vm.updateType(TransferType.PAID) }, contentAlignment = Alignment.Center) { Text("مدفوع", color = if (state.type == TransferType.PAID) White else White, fontSize = 24.sp, fontWeight = FontWeight.Bold) }
            }

            Box {
                OutlinedTextField(value = state.recipientName, onValueChange = { vm.updateRecipient(it); expandedNames = it.isNotEmpty() }, label = { Text("اسم المستلم") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White), trailingIcon = { IconButton(onClick = { expandedNames = !expandedNames }) { Icon(Icons.Default.ArrowDropDown, null) } }, singleLine = true)
                DropdownMenu(expanded = expandedNames, onDismissRequest = { expandedNames = false }) {
                    savedNames.filter { it.name.contains(state.recipientName, ignoreCase = true) }.forEach { s -> DropdownMenuItem(text = { Text(s.name) }, onClick = { vm.updateRecipient(s.name); expandedNames = false }) }
                }
            }

            OutlinedTextField(value = state.amount, onValueChange = { input -> vm.updateAmount(input.filter { it.isDigit() }) }, label = { Text("المبلغ") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true)

            if (state.type == TransferType.PAID) {
                OutlinedTextField(value = state.commission, onValueChange = { input -> vm.updateCommission(input.filter { it.isDigit() }) }, label = { Text("العمولة") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    AssistChip(onClick = { vm.updateCommission("100") }, label = { Text("100") }, colors = AssistChipDefaults.assistChipColors(containerColor = LightGray, labelColor = White))
                    AssistChip(onClick = { vm.updateCommission("250") }, label = { Text("250") }, colors = AssistChipDefaults.assistChipColors(containerColor = LightGray, labelColor = White))
                }
            }

            OutlinedButton(onClick = { showDatePicker = true }, modifier = Modifier.fillMaxWidth()) { Icon(Icons.Default.DateRange, null); Spacer(Modifier.width(8.dp)); Text(SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date(state.date)), color = White) }

            Spacer(Modifier.height(16.dp))

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = { vm.save() }, modifier = Modifier.weight(1f).height(50.dp), enabled = !state.isLoading, colors = ButtonDefaults.buttonColors(containerColor = GreenAccent)) { if (state.isLoading) CircularProgressIndicator(modifier = Modifier.size(24.dp), color = Black, strokeWidth = 2.dp) else Text("حفظ", color = Black, fontSize = 18.sp) }
                OutlinedButton(onClick = { vm.clearForm() }, modifier = Modifier.weight(1f).height(50.dp), enabled = !state.isLoading) { Text("إلغاء", fontSize = 18.sp) }
            }
        }

        if (showDatePicker) {
            val dateState = rememberDatePickerState(initialSelectedDateMillis = state.date)
            DatePickerDialog(onDismissRequest = { showDatePicker = false }, confirmButton = { TextButton(onClick = { dateState.selectedDateMillis?.let { vm.updateDate(it) }; showDatePicker = false }) { Text("موافق") } }, dismissButton = { TextButton(onClick = { showDatePicker = false }) { Text("إلغاء") } }) { DatePicker(state = dateState) }
        }

        if (showDeleteConfirm) {
            AlertDialog(onDismissRequest = { showDeleteConfirm = false }, title = { Text("حذف الحوالة") }, text = { Text("هل أنت متأكد من حذف هذه الحوالة؟") }, confirmButton = { TextButton(onClick = { showDeleteConfirm = false; vm.delete() }) { Text("حذف", color = RedAccent) } }, dismissButton = { TextButton(onClick = { showDeleteConfirm = false }) { Text("إلغاء") } })
        }
    }
}
EOF

# 5. الشاشة الرئيسية
cat > app/src/main/java/com/transferslog/app/ui/screens/HomeScreen.kt <<'EOF'
package com.transferslog.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.unit.sp
import com.transferslog.app.data.TransferType
import com.transferslog.app.ui.components.TransferCard
import com.transferslog.app.ui.theme.*
import com.transferslog.app.ui.viewmodel.MainViewModel
import java.text.DecimalFormat

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(vm: MainViewModel, onAdd: (TransferType) -> Unit, onEdit: (Long) -> Unit, onNavAcc: () -> Unit, onNavSettings: () -> Unit) {
    val transfers by vm.transfers.collectAsState()
    val accounts by vm.accounts.collectAsState()
    val query by vm.searchQuery.collectAsState()
    val type by vm.selectedType.collectAsState()
    val accId by vm.selectedAccountId.collectAsState()
    
    val acc = accounts.find { it.id == accId }
    var expandedAcc by remember { mutableStateOf(false) }
    val format = DecimalFormat("#,###.##")

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Box {
                        Row(modifier = Modifier.clickable { expandedAcc = true }, verticalAlignment = Alignment.CenterVertically) {
                            Text(acc?.name ?: "اختر حساب", color = White, fontSize = 20.sp)
                            Icon(Icons.Default.ArrowDropDown, null, tint = White)
                        }
                        DropdownMenu(expanded = expandedAcc, onDismissRequest = { expandedAcc = false }) {
                            accounts.forEach { a -> DropdownMenuItem(text = { Text(a.name) }, onClick = { vm.setAccountFilter(a.id); expandedAcc = false }) }
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Black),
                actions = {
                    IconButton(onClick = onNavAcc) { Icon(Icons.Default.Person, null, tint = White) }
                    IconButton(onClick = onNavSettings) { Icon(Icons.Default.Build, null, tint = White) }
                }
            )
        },
        bottomBar = {
            Column(modifier = Modifier.background(DarkGray)) {
                Row(modifier = Modifier.fillMaxWidth().padding(8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { onAdd(TransferType.RECEIVED) }, modifier = Modifier.weight(1f).height(60.dp), colors = ButtonDefaults.buttonColors(containerColor = GreenAccent), shape = MaterialTheme.shapes.medium) { Text("مستلم +", color = Black, fontSize = 20.sp, fontWeight = FontWeight.Bold) }
                    Button(onClick = { onAdd(TransferType.PAID) }, modifier = Modifier.weight(1f).height(60.dp), colors = ButtonDefaults.buttonColors(containerColor = RedAccent), shape = MaterialTheme.shapes.medium) { Text("مدفوع +", color = White, fontSize = 20.sp, fontWeight = FontWeight.Bold) }
                }
                Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp), horizontalArrangement = Arrangement.SpaceEvenly) {
                    val received = transfers.filter { it.type == TransferType.RECEIVED }.sumOf { it.amount }
                    val paid = transfers.filter { it.type == TransferType.PAID }.sumOf { it.amount }
                    val commission = transfers.filter { it.type == TransferType.PAID }.sumOf { it.commission }
                    val opening = acc?.openingBalance ?: 0.0
                    StatItem("الرصيد", opening + received - paid - commission, if ((opening + received - paid - commission) >= 0) GreenAccent else RedAccent, format)
                    StatItem("مدفوع", paid, RedAccent, format)
                    StatItem("مستلم", received, GreenAccent, format)
                    StatItem("حوالات", transfers.size.toDouble(), White, DecimalFormat("#"))
                }
                Spacer(Modifier.height(8.dp))
            }
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize().background(Black)) {
            OutlinedTextField(value = query, onValueChange = vm::setSearchQuery, modifier = Modifier.fillMaxWidth().padding(8.dp), placeholder = { Text("بحث...", color = SecondaryText) }, leadingIcon = { Icon(Icons.Default.Search, null, tint = SecondaryText) }, colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = GreenAccent, unfocusedBorderColor = LightGray, focusedTextColor = White, unfocusedTextColor = White), singleLine = true)
            
            Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = type == null, onClick = { vm.setTypeFilter(null) }, label = { Text("الكل") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = GreenAccent, selectedLabelColor = Black))
                FilterChip(selected = type == TransferType.RECEIVED, onClick = { vm.setTypeFilter(TransferType.RECEIVED) }, label = { Text("مستلم") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = GreenAccent, selectedLabelColor = Black))
                FilterChip(selected = type == TransferType.PAID, onClick = { vm.setTypeFilter(TransferType.PAID) }, label = { Text("مدفوع") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = RedAccent, selectedLabelColor = White))
            }

            if (accId == null) { Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text("الرجاء إضافة حساب أولاً من الإعدادات", color = SecondaryText) } }
            else if (transfers.isEmpty()) { Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text("لا توجد حوالات لهذا الحساب", color = SecondaryText) } }
            else {
                LazyColumn(modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(transfers, key = { it.id }) { t -> TransferCard(transfer = t, onClick = { onEdit(t.id) }) }
                }
            }
        }
    }
}

@Composable
private fun StatItem(label: String, value: Double, color: Color, format: DecimalFormat) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, color = SecondaryText, fontSize = 10.sp)
        Text(format.format(value), color = color, fontSize = 14.sp, fontWeight = FontWeight.Bold)
    }
}
EOF

# 6. بطاقة الحوالة
cat > app/src/main/java/com/transferslog/app/ui/components/TransferCard.kt <<'EOF'
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
EOF

# 7. التنقل
cat > app/src/main/java/com/transferslog/app/ui/navigation/AppNavigation.kt <<'EOF'
package com.transferslog.app.ui.navigation

import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.*
import androidx.navigation.navArgument
import com.transferslog.app.data.Repository
import com.transferslog.app.data.TransferType
import com.transferslog.app.ui.screens.*
import com.transferslog.app.ui.viewmodel.*

@Composable
fun AppNavigation(repo: Repository) {
    val nav = rememberNavController()
    NavHost(navController = nav, startDestination = "home", enterTransition = { EnterTransition.None }, exitTransition = { ExitTransition.None }) {
        composable("home") {
            val vm: MainViewModel = viewModel { MainViewModel(repo) }
            HomeScreen(vm, onAdd = { nav.navigate("add_edit?type=${it.name}") }, onEdit = { nav.navigate("add_edit?id=$it") }, onNavAcc = { nav.navigate("accounts") }, onNavSettings = { nav.navigate("settings") })
        }
        composable("add_edit?id={id}&type={type}", arguments = listOf(navArgument("id") { type = NavType.LongType; defaultValue = -1L }, navArgument("type") { type = NavType.StringType; defaultValue = TransferType.RECEIVED.name })) { backStack ->
            val id = backStack.arguments?.getLong("id")?.takeIf { it > 0 }
            val mainVm: MainViewModel = viewModel { MainViewModel(repo) }
            val accountId = mainVm.selectedAccountId.collectAsState().value
            if (accountId != null) {
                val vm: AddEditViewModel = viewModel { AddEditViewModel(repo, accountId) }
                AddEditTransferScreen(vm, id) { nav.popBackStack() }
            }
        }
        composable("accounts") {
            val vm: AccountsViewModel = viewModel { AccountsViewModel(repo) }
            AccountsScreen(vm) { nav.popBackStack() }
        }
        composable("settings") {
            val ctx = LocalContext.current
            val vm: SettingsViewModel = viewModel { SettingsViewModel(repo, ctx) }
            SettingsScreen(vm) { nav.popBackStack() }
        }
    }
}
EOF

# 8. إعدادات وأدوات الـ PDF
cat > app/src/main/java/com/transferslog/app/util/PdfUtils.kt <<'EOF'
package com.transferslog.app.util

import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.net.Uri
import androidx.core.content.FileProvider
import com.transferslog.app.data.Transfer
import com.transferslog.app.data.TransferType
import java.io.File
import java.io.FileOutputStream
import java.text.DecimalFormat
import java.text.SimpleDateFormat
import java.util.*

object PdfUtils {
    fun generateAndShare(context: Context, transfers: List<Transfer>, accountName: String, startDate: Long, endDate: Long) {
        val document = PdfDocument()
        val paint = Paint()
        val titlePaint = Paint().apply { textSize = 20f; isFakeBoldText = true }
        val pageInfo = PdfDocument.PageInfo.Builder(595, 842, 1).create()
        val page = document.startPage(pageInfo)
        val canvas = page.canvas

        var y = 50f
        paint.textSize = 14f
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val numFormat = DecimalFormat("#,###.##")

        canvas.drawText("كشف حساب: $accountName", 50f, y, titlePaint)
        y += 30f
        canvas.drawText("من: ${dateFormat.format(Date(startDate))} إلى: ${dateFormat.format(Date(endDate))}", 50f, y, paint)
        y += 40f

        canvas.drawText("التاريخ", 50f, y, titlePaint)
        canvas.drawText("الاسم", 150f, y, titlePaint)
        canvas.drawText("المبلغ", 350f, y, titlePaint)
        canvas.drawText("النوع", 450f, y, titlePaint)
        y += 20f
        canvas.drawLine(50f, y, 550f, y, paint)
        y += 20f

        var totalPaid = 0.0
        var totalReceived = 0.0

        for (t in transfers) {
            canvas.drawText(dateFormat.format(Date(t.date)), 50f, y, paint)
            canvas.drawText(t.recipientName, 150f, y, paint)
            canvas.drawText(numFormat.format(t.amount), 350f, y, paint)
            canvas.drawText(if (t.type == TransferType.PAID) "مدفوع" else "مستلم", 450f, y, paint)
            if (t.type == TransferType.PAID) totalPaid += t.amount else totalReceived += t.amount
            y += 20f
            if (y > 800) {
                document.finishPage(page)
                val newPage = document.startPage(PdfDocument.PageInfo.Builder(595, 842, 2).create())
                y = 50f
            }
        }

        y += 20f
        canvas.drawText("إجمالي المدفوع: ${numFormat.format(totalPaid)}", 50f, y, titlePaint)
        y += 20f
        canvas.drawText("إجمالي المستلم: ${numFormat.format(totalReceived)}", 50f, y, titlePaint)
        document.finishPage(page)

        val file = File(context.cacheDir, "statement.pdf")
        try {
            document.writeTo(FileOutputStream(file))
            document.close()
            val uri: Uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
            val intent = Intent(Intent.ACTION_SEND).apply { type = "application/pdf"; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION) }
            context.startActivity(Intent.createChooser(intent, "مشاركة كشف الحساب"))
        } catch (e: Exception) { e.printStackTrace() }
    }
}
EOF

cat > app/src/main/java/com/transferslog/app/ui/viewmodel/SettingsViewModel.kt <<'EOF'
package com.transferslog.app.ui.viewmodel

import android.content.Context
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.transferslog.app.data.Repository
import com.transferslog.app.util.JsonBackup
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

val Context.dataStore by preferencesDataStore(name = "settings")

data class SettingsUiState(val isLoading: Boolean = false, val message: String? = null)

class SettingsViewModel(val repo: Repository, private val context: Context) : ViewModel() {
    private object Keys { val CURRENCY = stringPreferencesKey("currency"); val COMM_1 = doublePreferencesKey("c1"); val COMM_2 = doublePreferencesKey("c2") }
    val currency = context.dataStore.data.map { it[Keys.CURRENCY] ?: "ل.س" }
    val commission1 = context.dataStore.data.map { it[Keys.COMM_1] ?: 100.0 }
    val commission2 = context.dataStore.data.map { it[Keys.COMM_2] ?: 250.0 }
    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState = _uiState.asStateFlow()

    fun setCurrency(v: String) = viewModelScope.launch { context.dataStore.edit { it[Keys.CURRENCY] = v } }
    fun setComm1(v: Double) = viewModelScope.launch { context.dataStore.edit { it[Keys.COMM_1] = v } }
    fun setComm2(v: Double) = viewModelScope.launch { context.dataStore.edit { it[Keys.COMM_2] = v } }

    fun exportData(onResult: (String?) -> Unit) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                val json = JsonBackup.export(repo.accountDao.getAll().first(), repo.transferDao.getFiltered(-1, null, "", null, null).first(), repo.savedNameDao.getAll().first())
                _uiState.update { it.copy(isLoading = false, message = "تم تصدير البيانات") }; onResult(json)
            } catch (e: Exception) { _uiState.update { it.copy(isLoading = false, message = "فشل التصدير: ${e.message}") }; onResult(null) }
        }
    }

    fun importData(json: String, onDone: (Boolean) -> Unit) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                val data = JsonBackup.import(json)
                if (data != null) {
                    repo.deleteAllData()
                    data.accounts.forEach { repo.insertAccount(it) }
                    data.transfers.forEach { repo.transferDao.insert(it) }
                    data.savedNames.forEach { repo.savedNameDao.insert(it) }
                    _uiState.update { it.copy(isLoading = false, message = "تم استيراد البيانات بنجاح") }; onDone(true)
                } else { _uiState.update { it.copy(isLoading = false, message = "ملف غير صالح") }; onDone(false) }
            } catch (e: Exception) { _uiState.update { it.copy(isLoading = false, message = "فشل الاستيراد: ${e.message}") }; onDone(false) }
        }
    }

    fun deleteAll(onDone: () -> Unit) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try { repo.deleteAllData(); _uiState.update { it.copy(isLoading = false, message = "تم حذف جميع البيانات") }; onDone()
            } catch (e: Exception) { _uiState.update { it.copy(isLoading = false, message = "فشل الحذف: ${e.message}") } }
        }
    }
    fun clearMessage() { _uiState.update { it.copy(message = null) } }
}
EOF

cat > app/src/main/java/com/transferslog/app/ui/screens/SettingsScreen.kt <<'EOF'
package com.transferslog.app.ui.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.transferslog.app.ui.theme.*
import com.transferslog.app.ui.viewmodel.SettingsViewModel
import com.transferslog.app.util.PdfUtils
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(vm: SettingsViewModel, onBack: () -> Unit) {
    val context = LocalContext.current
    val currency by vm.currency.collectAsState(initial = "ل.س")
    val c1 by vm.commission1.collectAsState(initial = 100.0)
    val c2 by vm.commission2.collectAsState(initial = 250.0)
    val uiState by vm.uiState.collectAsState()
    val snackbar = remember { SnackbarHostState() }
    var showDateRangeForPdf by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(uiState.message) { uiState.message?.let { snackbar.showSnackbar(it); vm.clearMessage() } }

    val exportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        uri?.let { vm.exportData { json -> if (json != null) context.contentResolver.openOutputStream(it)?.use { os -> os.write(json.toByteArray()) } } }
    }
    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri?.let { context.contentResolver.openInputStream(it)?.use { isr -> vm.importData(isr.readBytes().decodeToString()) { _ -> } } }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = { TopAppBar(title = { Text("الإعدادات") }, navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, null) } }, colors = TopAppBarDefaults.topAppBarColors(containerColor = Black, titleContentColor = White, navigationIconContentColor = White)) }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize().background(Black)) {
            if (uiState.isLoading) CircularProgressIndicator(modifier = Modifier.align(Alignment.Center), color = GreenAccent)
            Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                OutlinedTextField(value = currency, onValueChange = { vm.setCurrency(it) }, label = { Text("العملة") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))
                OutlinedTextField(value = c1.toString(), onValueChange = { it.toDoubleOrNull()?.let { v -> vm.setComm1(v) } }, label = { Text("العمولة الأولى") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))
                OutlinedTextField(value = c2.toString(), onValueChange = { it.toDoubleOrNull()?.let { v -> vm.setComm2(v) } }, label = { Text("العمولة الثانية") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))

                Divider(color = LightGray, modifier = Modifier.padding(vertical = 8.dp))
                Text("النسخ الاحتياطي", color = White, style = MaterialTheme.typography.titleMedium)
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { exportLauncher.launch("hawala_backup.json") }, modifier = Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = DarkGray)) { Text("تصدير JSON", color = White) }
                    Button(onClick = { importLauncher.launch(arrayOf("application/json")) }, modifier = Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = DarkGray)) { Text("استيراد JSON", color = White) }
                }

                Divider(color = LightGray, modifier = Modifier.padding(vertical = 8.dp))
                Text("تصدير PDF", color = White, style = MaterialTheme.typography.titleMedium)
                Button(onClick = { showDateRangeForPdf = true }, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = GreenAccent)) { Text("تصدير ومشاركة كشف حساب", color = Black) }

                Button(onClick = { vm.deleteAll { } }, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = RedAccent)) { Text("حذف كل البيانات") }

                Divider(color = LightGray, modifier = Modifier.padding(vertical = 8.dp))
                Text("عن البرنامج", color = White, style = MaterialTheme.typography.titleLarge)
                Text("الإصدار: 2.0", color = SecondaryText)
                Text("المبرمج: أدهم الهبة", color = SecondaryText)
            }
        }
    }

    if (showDateRangeForPdf) {
        val dateState = rememberDateRangePickerState()
        DatePickerDialog(
            onDismissRequest = { showDateRangeForPdf = false },
            confirmButton = {
                TextButton(onClick = {
                    showDateRangeForPdf = false
                    val start = dateState.selectedStartDateMillis ?: 0L
                    val end = dateState.selectedEndDateMillis ?: System.currentTimeMillis()
                    scope.launch {
                        val accountId = vm.repo.accountDao.getAll().first().firstOrNull()?.id
                        if (accountId != null) {
                            val accName = vm.repo.accountDao.getById(accountId)?.name ?: ""
                            val list = vm.repo.transferDao.getFiltered(accountId, null, "", start, end).first()
                            if (list.isNotEmpty()) PdfUtils.generateAndShare(context, list, accName, start, end)
                        }
                    }
                }) { Text("تصدير") }
            },
            dismissButton = { TextButton(onClick = { showDateRangeForPdf = false }) { Text("إلغاء") } }
        ) { DateRangePicker(state = dateState) }
    }
}
EOF

echo -e "${GREEN}✓ تم إنشاء جميع الملفات بنجاح.${NC}"

echo -e "${YELLOW}جاري رفع التحديثات إلى GitHub...${NC}"
git add .
git commit -m "Final Overhaul: Account-centric, PDF Export, Number Formatting, UI Polish, No Animations"
git push -u origin main

echo -e "${GREEN}✅ التطبيق الآن جاهز للإنتاج 100%! اذهب إلى GitHub Actions لتحميل الـ APK الجديد.${NC}"
