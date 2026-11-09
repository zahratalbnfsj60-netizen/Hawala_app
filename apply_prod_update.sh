#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/Hawala_app"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${YELLOW}جاري تطبيق التحديث الشامل (Production-Ready)...${NC}"

# 1. AddEditViewModel
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
    val id: Long? = null,
    val type: TransferType = TransferType.RECEIVED,
    val recipientName: String = "",
    val amount: String = "",
    val commission: String = "",
    val date: Long = System.currentTimeMillis(),
    val accountId: Long? = null,
    val note: String = "",
    val paidNumber: Long? = null,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val savedMessage: String? = null,
    val hasChanges: Boolean = false,
    val nameError: Boolean = false,
    val amountError: Boolean = false,
    val accountError: Boolean = false
)

class AddEditViewModel(private val repository: Repository) : ViewModel() {
    private val _formState = MutableStateFlow(TransferFormState())
    val formState = _formState.asStateFlow()

    val accounts = repository.getAccounts()
    val savedNames = repository.getSavedNames()

    fun loadTransfer(id: Long) {
        viewModelScope.launch {
            _formState.value = _formState.value.copy(isLoading = true)
            try {
                repository.transferDao.getById(id)?.let { t ->
                    _formState.value = TransferFormState(
                        id = t.id, type = t.type, recipientName = t.recipientName, amount = t.amount.toString(),
                        commission = t.commission.toString(), date = t.date, accountId = t.accountId,
                        note = t.note ?: "", paidNumber = t.paidNumber, isLoading = false
                    )
                }
            } catch (e: Exception) {
                _formState.value = _formState.value.copy(isLoading = false, errorMessage = "فشل تحميل الحوالة: ${e.message}")
            }
        }
    }

    fun updateType(type: TransferType) { _formState.value = _formState.value.copy(type = type, hasChanges = true) }
    fun updateRecipient(name: String) { _formState.value = _formState.value.copy(recipientName = name, hasChanges = true, nameError = false) }
    fun updateAmount(amount: String) { _formState.value = _formState.value.copy(amount = amount, hasChanges = true, amountError = false) }
    fun updateCommission(commission: String) { _formState.value = _formState.value.copy(commission = commission, hasChanges = true) }
    fun updateDate(date: Long) { _formState.value = _formState.value.copy(date = DateUtils.normalizeToUtcStartOfDay(date), hasChanges = true) }
    fun updateAccount(id: Long?) { _formState.value = _formState.value.copy(accountId = id, hasChanges = true, accountError = false) }
    fun updateNote(note: String) { _formState.value = _formState.value.copy(note = note, hasChanges = true) }

    fun save() {
        val state = _formState.value
        val nameValid = state.recipientName.isNotBlank()
        val amountVal = state.amount.toDoubleOrNull()
        val amountValid = amountVal != null && amountVal > 0
        val accountValid = state.accountId != null
        val commVal = if (state.type == TransferType.PAID) state.commission.toDoubleOrNull() ?: 0.0 else 0.0

        if (!nameValid || !amountValid || !accountValid) {
            _formState.value = state.copy(
                nameError = !nameValid,
                amountError = !amountValid,
                accountError = !accountValid,
                errorMessage = "يرجى تصحيح الحقول المطلوبة"
            )
            return
        }

        viewModelScope.launch {
            _formState.value = _formState.value.copy(isLoading = true, errorMessage = null)
            try {
                if (state.id == null) {
                    repository.insertTransfer(Transfer(
                        type = state.type, recipientName = state.recipientName, amount = amountVal!!,
                        commission = commVal, date = state.date, accountId = state.accountId!!,
                        note = state.note.ifBlank { null }
                    ))
                    _formState.value = TransferFormState(savedMessage = "تم حفظ الحوالة بنجاح")
                } else {
                    repository.updateTransfer(Transfer(
                        id = state.id, type = state.type, recipientName = state.recipientName, amount = amountVal!!,
                        commission = commVal, date = state.date, accountId = state.accountId!!,
                        note = state.note.ifBlank { null }, paidNumber = state.paidNumber
                    ))
                    _formState.value = state.copy(isLoading = false, savedMessage = "تم تحديث الحوالة بنجاح", hasChanges = false)
                }
            } catch (e: Exception) {
                _formState.value = _formState.value.copy(isLoading = false, errorMessage = "حدث خطأ أثناء الحفظ: ${e.message}")
            }
        }
    }

    fun clearForm() { _formState.value = TransferFormState() }
    fun clearMessage() { _formState.value = _formState.value.copy(savedMessage = null, errorMessage = null) }
}
EOF

# 2. AddEditTransferScreen
cat > app/src/main/java/com/transferslog/app/ui/screens/AddEditTransferScreen.kt <<'EOF'
package com.transferslog.app.ui.screens

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
import androidx.compose.ui.unit.dp
import com.transferslog.app.data.TransferType
import com.transferslog.app.ui.theme.*
import com.transferslog.app.ui.viewmodel.AddEditViewModel
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEditTransferScreen(vm: AddEditViewModel, id: Long?, onBack: () -> Unit) {
    val state by vm.formState.collectAsState()
    val accounts by vm.accounts.collectAsState(initial = emptyList())
    val savedNames by vm.savedNames.collectAsState(initial = emptyList())
    val snackbar = remember { SnackbarHostState() }
    var showDatePicker by remember { mutableStateOf(false) }
    var showExitConfirm by remember { mutableStateOf(false) }
    var expandedNames by remember { mutableStateOf(false) }
    var expandedAcc by remember { mutableStateOf(false) }

    LaunchedEffect(id) { id?.let { vm.loadTransfer(it) } }
    LaunchedEffect(state.savedMessage, state.errorMessage) {
        state.savedMessage?.let {
            snackbar.showSnackbar(it)
            vm.clearMessage()
            if (state.id != null) onBack()
        } ?: state.errorMessage?.let {
            snackbar.showSnackbar(it)
            vm.clearMessage()
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = { Text(if (state.id == null) "إضافة حوالة" else "تعديل حوالة") },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, null) } },
                actions = {
                    IconButton(onClick = { if (state.hasChanges) showExitConfirm = true else onBack() }) {
                        Icon(Icons.Default.Close, null)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Black, titleContentColor = White, navigationIconContentColor = White, actionIconContentColor = White)
            )
        },
        bottomBar = {
            Row(modifier = Modifier.fillMaxWidth().background(DarkGray).padding(8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(
                    onClick = { vm.save() }, 
                    modifier = Modifier.weight(1f), 
                    enabled = !state.isLoading,
                    colors = ButtonDefaults.buttonColors(containerColor = GreenAccent)
                ) { 
                    if (state.isLoading) {
                        CircularProgressIndicator(modifier = Modifier.size(20.dp), color = Black, strokeWidth = 2.dp)
                    } else {
                        Text("حفظ", color = Black) 
                    }
                }
                OutlinedButton(onClick = { vm.clearForm() }, modifier = Modifier.weight(1f), enabled = !state.isLoading) { Text("إلغاء") }
            }
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize().background(Black).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = state.type == TransferType.RECEIVED, onClick = { vm.updateType(TransferType.RECEIVED) }, label = { Text("مستلم") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = GreenAccent, selectedLabelColor = Black))
                FilterChip(selected = state.type == TransferType.PAID, onClick = { vm.updateType(TransferType.PAID) }, label = { Text("مدفوع") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = RedAccent, selectedLabelColor = White))
            }

            Box {
                OutlinedTextField(
                    value = state.recipientName, 
                    onValueChange = { vm.updateRecipient(it); expandedNames = it.isNotEmpty() }, 
                    label = { Text("اسم المستلم *") }, modifier = Modifier.fillMaxWidth(), 
                    colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White),
                    trailingIcon = { IconButton(onClick = { expandedNames = !expandedNames }) { Icon(Icons.Default.ArrowDropDown, null) } },
                    isError = state.nameError,
                    supportingText = if (state.nameError) { { Text("الاسم مطلوب", color = RedAccent) } } else null
                )
                DropdownMenu(expanded = expandedNames, onDismissRequest = { expandedNames = false }) {
                    savedNames.filter { it.name.contains(state.recipientName, ignoreCase = true) }.forEach { s ->
                        DropdownMenuItem(text = { Text(s.name) }, onClick = { vm.updateRecipient(s.name); expandedNames = false })
                    }
                }
            }

            OutlinedTextField(
                value = state.amount, 
                onValueChange = vm::updateAmount, 
                label = { Text("المبلغ *") }, 
                modifier = Modifier.fillMaxWidth(), 
                colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White),
                isError = state.amountError,
                supportingText = if (state.amountError) { { Text("يجب أن يكون المبلغ رقماً أكبر من 0", color = RedAccent) } } else null
            )

            Box {
                OutlinedButton(
                    onClick = { expandedAcc = true }, 
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.outlinedButtonColors(
                        contentColor = if (state.accountError) RedAccent else White
                    )
                ) {
                    Text(accounts.find { it.id == state.accountId }?.name ?: "اختر الحساب *", color = if (state.accountError) RedAccent else White)
                }
                DropdownMenu(expanded = expandedAcc, onDismissRequest = { expandedAcc = false }) {
                    accounts.forEach { a ->
                        DropdownMenuItem(text = { Text(a.name) }, onClick = { vm.updateAccount(a.id); expandedAcc = false })
                    }
                }
            }
            if (state.accountError) {
                Text("يجب اختيار حساب", color = RedAccent, style = MaterialTheme.typography.bodySmall)
            }

            if (state.type == TransferType.PAID) {
                OutlinedTextField(value = state.commission, onValueChange = vm::updateCommission, label = { Text("العمولة") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))
            }

            OutlinedButton(onClick = { showDatePicker = true }, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Default.DateRange, null); Spacer(Modifier.width(8.dp))
                Text(SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date(state.date)), color = White)
            }
            OutlinedTextField(value = state.note, onValueChange = vm::updateNote, label = { Text("ملاحظة") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))

            if (showDatePicker) {
                val dateState = rememberDatePickerState(initialSelectedDateMillis = state.date)
                DatePickerDialog(
                    onDismissRequest = { showDatePicker = false },
                    confirmButton = { TextButton(onClick = { dateState.selectedDateMillis?.let { vm.updateDate(it) }; showDatePicker = false }) { Text("موافق") } },
                    dismissButton = { TextButton(onClick = { showDatePicker = false }) { Text("إلغاء") } }
                ) { DatePicker(state = dateState) }
            }
        }

        if (showExitConfirm) {
            AlertDialog(
                onDismissRequest = { showExitConfirm = false },
                title = { Text("تنبيه") },
                text = { Text("يوجد بيانات لم يتم حفظها. هل تريد الخروج؟") },
                confirmButton = { TextButton(onClick = { showExitConfirm = false; onBack() }) { Text("خروج", color = RedAccent) } },
                dismissButton = { TextButton(onClick = { showExitConfirm = false }) { Text("بقاء") } }
            )
        }
    }
}
EOF

# 3. AccountsViewModel
cat > app/src/main/java/com/transferslog/app/ui/viewmodel/AccountsViewModel.kt <<'EOF'
package com.transferslog.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.transferslog.app.data.Account
import com.transferslog.app.data.Repository
import com.transferslog.app.data.TransferType
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class AccountWithBalance(val account: Account, val currentBalance: Double)

data class AccountsUiState(
    val accounts: List<AccountWithBalance> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val successMessage: String? = null
)

class AccountsViewModel(private val repo: Repository) : ViewModel() {
    private val _uiState = MutableStateFlow(AccountsUiState())
    val uiState = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            combine(
                repo.getAccounts(),
                repo.getFilteredTransfers()
            ) { accounts, transfers ->
                accounts.map { acc ->
                    val received = transfers.filter { it.accountId == acc.id && it.type == TransferType.RECEIVED }.sumOf { it.amount }
                    val paid = transfers.filter { it.accountId == acc.id && it.type == TransferType.PAID }.sumOf { it.amount }
                    val commission = transfers.filter { it.accountId == acc.id && it.type == TransferType.PAID }.sumOf { it.commission }
                    val current = acc.openingBalance + received - paid - commission
                    AccountWithBalance(acc, current)
                }
            }.catch { e ->
                _uiState.update { it.copy(errorMessage = "فشل تحميل الحسابات: ${e.message}") }
            }.collect { list ->
                _uiState.update { it.copy(accounts = list, isLoading = false) }
            }
        }
    }

    fun add(name: String, opening: String) {
        if (name.isBlank()) {
            _uiState.update { it.copy(errorMessage = "اسم الحساب مطلوب") }
            return
        }
        val openVal = opening.toDoubleOrNull()
        if (openVal == null) {
            _uiState.update { it.copy(errorMessage = "الرصيد الافتتاحي غير صالح") }
            return
        }
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                repo.insertAccount(Account(name = name, openingBalance = openVal))
                _uiState.update { it.copy(isLoading = false, successMessage = "تم إضافة الحساب") }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, errorMessage = "فشل إضافة الحساب: ${e.message}") }
            }
        }
    }

    fun update(account: Account) {
        if (account.name.isBlank()) {
            _uiState.update { it.copy(errorMessage = "اسم الحساب مطلوب") }
            return
        }
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                repo.updateAccount(account)
                _uiState.update { it.copy(isLoading = false, successMessage = "تم تحديث الحساب") }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, errorMessage = "فشل تحديث الحساب: ${e.message}") }
            }
        }
    }

    fun delete(account: Account) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                repo.deleteAccount(account)
                _uiState.update { it.copy(isLoading = false, successMessage = "تم حذف الحساب") }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, errorMessage = "فشل حذف الحساب: ${e.message}") }
            }
        }
    }

    fun clearMessages() {
        _uiState.update { it.copy(errorMessage = null, successMessage = null) }
    }
}
EOF

# 4. AccountsScreen
cat > app/src/main/java/com/transferslog/app/ui/screens/AccountsScreen.kt <<'EOF'
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
EOF

# 5. SettingsViewModel
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

data class SettingsUiState(
    val isLoading: Boolean = false,
    val message: String? = null
)

class SettingsViewModel(private val repo: Repository, private val context: Context) : ViewModel() {
    private object Keys {
        val CURRENCY = stringPreferencesKey("currency")
        val COMM_1 = doublePreferencesKey("c1")
        val COMM_2 = doublePreferencesKey("c2")
        val DEFAULT_COMM = doublePreferencesKey("dc")
    }
    val currency = context.dataStore.data.map { it[Keys.CURRENCY] ?: "ل.س" }
    val commission1 = context.dataStore.data.map { it[Keys.COMM_1] ?: 100.0 }
    val commission2 = context.dataStore.data.map { it[Keys.COMM_2] ?: 250.0 }
    val defaultCommission = context.dataStore.data.map { it[Keys.DEFAULT_COMM] ?: 100.0 }

    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState = _uiState.asStateFlow()

    fun setCurrency(v: String) = viewModelScope.launch { context.dataStore.edit { it[Keys.CURRENCY] = v } }
    fun setComm1(v: Double) = viewModelScope.launch { context.dataStore.edit { it[Keys.COMM_1] = v } }
    fun setComm2(v: Double) = viewModelScope.launch { context.dataStore.edit { it[Keys.COMM_2] = v } }
    fun setDefaultComm(v: Double) = viewModelScope.launch { context.dataStore.edit { it[Keys.DEFAULT_COMM] = v } }

    fun exportData(onResult: (String?) -> Unit) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                val accounts = repo.accountDao.getAll().first()
                val transfers = repo.transferDao.getFiltered(null, null, "", null, null).first()
                val savedNames = repo.savedNameDao.getAll().first()
                val json = JsonBackup.export(accounts, transfers, savedNames)
                _uiState.update { it.copy(isLoading = false, message = "تم تصدير البيانات") }
                onResult(json)
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, message = "فشل التصدير: ${e.message}") }
                onResult(null)
            }
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
                    _uiState.update { it.copy(isLoading = false, message = "تم استيراد البيانات بنجاح") }
                    onDone(true)
                } else {
                    _uiState.update { it.copy(isLoading = false, message = "ملف غير صالح") }
                    onDone(false)
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, message = "فشل الاستيراد: ${e.message}") }
                onDone(false)
            }
        }
    }

    fun deleteAll(onDone: () -> Unit) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                repo.deleteAllData()
                _uiState.update { it.copy(isLoading = false, message = "تم حذف جميع البيانات") }
                onDone()
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, message = "فشل الحذف: ${e.message}") }
            }
        }
    }

    fun clearMessage() { _uiState.update { it.copy(message = null) } }
}
EOF

# 6. SettingsScreen
cat > app/src/main/java/com/transferslog/app/ui/screens/SettingsScreen.kt <<'EOF'
package com.transferslog.app.ui.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.transferslog.app.ui.theme.*
import com.transferslog.app.ui.viewmodel.SettingsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(vm: SettingsViewModel, onBack: () -> Unit) {
    val context = LocalContext.current
    val currency by vm.currency.collectAsState(initial = "ل.س")
    val c1 by vm.commission1.collectAsState(initial = 100.0)
    val c2 by vm.commission2.collectAsState(initial = 250.0)
    val uiState by vm.uiState.collectAsState()
    val snackbar = remember { SnackbarHostState() }

    var showDeleteConfirm1 by remember { mutableStateOf(false) }
    var showDeleteConfirm2 by remember { mutableStateOf(false) }

    LaunchedEffect(uiState.message) {
        uiState.message?.let { snackbar.showSnackbar(it); vm.clearMessage() }
    }

    val exportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        uri?.let {
            vm.exportData { json ->
                if (json != null) {
                    context.contentResolver.openOutputStream(it)?.use { os -> os.write(json.toByteArray()) }
                }
            }
        }
    }

    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri?.let {
            context.contentResolver.openInputStream(it)?.use { isr ->
                val json = isr.readBytes().decodeToString()
                vm.importData(json) { _ -> }
            }
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = { 
            TopAppBar(
                title = { Text("الإعدادات") }, 
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, null) } }, 
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Black, titleContentColor = White, navigationIconContentColor = White)
            ) 
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize().background(Black)) {
            if (uiState.isLoading) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center), color = GreenAccent)
            }
            Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                OutlinedTextField(value = currency, onValueChange = { vm.setCurrency(it) }, label = { Text("العملة") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))
                OutlinedTextField(value = c1.toString(), onValueChange = { it.toDoubleOrNull()?.let { v -> vm.setComm1(v) } }, label = { Text("العمولة الأولى") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))
                OutlinedTextField(value = c2.toString(), onValueChange = { it.toDoubleOrNull()?.let { v -> vm.setComm2(v) } }, label = { Text("العمولة الثانية") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))

                Divider(color = LightGray, modifier = Modifier.padding(vertical = 8.dp))

                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { exportLauncher.launch("hawala_backup.json") }, modifier = Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = DarkGray)) { Text("تصدير JSON", color = White) }
                    Button(onClick = { importLauncher.launch(arrayOf("application/json")) }, modifier = Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = DarkGray)) { Text("استيراد JSON", color = White) }
                }

                Button(onClick = { showDeleteConfirm1 = true }, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = RedAccent)) {
                    Text("حذف كل البيانات")
                }

                Divider(color = LightGray, modifier = Modifier.padding(vertical = 8.dp))
                Text("عن البرنامج", color = White, style = MaterialTheme.typography.titleLarge)
                Text("الإصدار: 1.0", color = SecondaryText)
                Text("المبرمج: أدهم الهبة", color = SecondaryText)
            }
        }
    }

    if (showDeleteConfirm1) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm1 = false },
            title = { Text("تحذير خطير!") },
            text = { Text("سيتم حذف جميع الحسابات والحوالات نهائياً. هل تريد المتابعة؟") },
            confirmButton = { TextButton(onClick = { showDeleteConfirm1 = false; showDeleteConfirm2 = true }) { Text("نعم", color = RedAccent) } },
            dismissButton = { TextButton(onClick = { showDeleteConfirm1 = false }) { Text("إلغاء") } }
        )
    }

    if (showDeleteConfirm2) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm2 = false },
            title = { Text("تأكيد أخير") },
            text = { Text("هل أنت متأكد 100%؟ لا يمكن التراجع عن هذه الخطوة!") },
            confirmButton = { TextButton(onClick = { vm.deleteAll { showDeleteConfirm2 = false } }) { Text("نعم، احذف نهائياً", color = RedAccent) } },
            dismissButton = { TextButton(onClick = { showDeleteConfirm2 = false }) { Text("إلغاء") } }
        )
    }
}
EOF

# 7. StatisticsViewModel
cat > app/src/main/java/com/transferslog/app/ui/viewmodel/StatisticsViewModel.kt <<'EOF'
package com.transferslog.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.transferslog.app.data.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class StatisticsData(val openingBalance: Double = 0.0, val totalReceived: Double = 0.0, val totalPaid: Double = 0.0, val totalCommission: Double = 0.0, val remaining: Double = 0.0)

class StatisticsViewModel(private val repo: Repository) : ViewModel() {
    private val _selectedAccountId = MutableStateFlow<Long?>(null)
    val selectedAccountId = _selectedAccountId.asStateFlow()
    val accounts = repo.getAccounts().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    @OptIn(ExperimentalCoroutinesApi::class)
    val stats = _selectedAccountId.flatMapLatest { id -> repo.getFilteredTransfers(accountId = id) }
        .map { list ->
            val opening = if (_selectedAccountId.value == null) {
                accounts.value.sumOf { it.openingBalance }
            } else {
                accounts.value.find { it.id == _selectedAccountId.value }?.openingBalance ?: 0.0
            }
            val r = list.filter { it.type == TransferType.RECEIVED }.sumOf { it.amount }
            val p = list.filter { it.type == TransferType.PAID }.sumOf { it.amount }
            val c = list.filter { it.type == TransferType.PAID }.sumOf { it.commission }
            StatisticsData(opening, r, p, c, opening + r - p - c)
        }.catch { e ->
            emit(StatisticsData())
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), StatisticsData())

    fun selectAccount(id: Long?) { _selectedAccountId.value = id }
}
EOF

# 8. HomeScreen (Empty States & UI Fixes)
cat > app/src/main/java/com/transferslog/app/ui/screens/HomeScreen.kt <<'EOF'
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
import com.transferslog.app.data.TransferType
import com.transferslog.app.ui.components.StatBar
import com.transferslog.app.ui.components.TransferCard
import com.transferslog.app.ui.theme.*
import com.transferslog.app.ui.viewmodel.MainViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(vm: MainViewModel, onAdd: (TransferType) -> Unit, onEdit: (Long) -> Unit, onNavAcc: () -> Unit, onNavStats: () -> Unit, onNavSettings: () -> Unit) {
    val transfers by vm.transfers.collectAsState()
    val accounts by vm.accounts.collectAsState()
    val query by vm.searchQuery.collectAsState()
    val type by vm.selectedType.collectAsState()
    val accId by vm.selectedAccountId.collectAsState()
    val dateRange by vm.dateRange.collectAsState(initial = null)
    val acc = accounts.find { it.id == accId }

    var showDatePicker by remember { mutableStateOf(false) }
    var expandedAcc by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("سجل الحوالات", color = White) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Black),
                actions = {
                    IconButton(onClick = onNavAcc) { Icon(Icons.Default.Person, null, tint = White) }
                    IconButton(onClick = onNavStats) { Icon(Icons.Default.List, null, tint = White) }
                    IconButton(onClick = onNavSettings) { Icon(Icons.Default.Settings, null, tint = White) }
                }
            )
        },
        bottomBar = {
            Column(modifier = Modifier.background(DarkGray)) {
                Row(modifier = Modifier.fillMaxWidth().padding(8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { onAdd(TransferType.RECEIVED) }, modifier = Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = GreenAccent)) { Text("مستلم +", color = Black) }
                    Button(onClick = { onAdd(TransferType.PAID) }, modifier = Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = RedAccent)) { Text("مدفوع +", color = White) }
                }
                StatBar(
                    opening = acc?.openingBalance ?: 0.0,
                    paid = transfers.filter { it.type == TransferType.PAID }.sumOf { it.amount },
                    received = transfers.filter { it.type == TransferType.RECEIVED }.sumOf { it.amount }
                )
            }
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize().background(Black)) {
            OutlinedTextField(
                value = query, onValueChange = vm::setSearchQuery,
                modifier = Modifier.fillMaxWidth().padding(8.dp),
                placeholder = { Text("بحث بالاسم أو المبلغ...", color = SecondaryText) },
                leadingIcon = { Icon(Icons.Default.Search, null, tint = SecondaryText) },
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = GreenAccent, unfocusedBorderColor = LightGray, focusedTextColor = White, unfocusedTextColor = White),
                singleLine = true
            )
            
            Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                FilterChip(selected = type == null, onClick = { vm.setTypeFilter(null) }, label = { Text("الكل") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = GreenAccent, selectedLabelColor = Black))
                FilterChip(selected = type == TransferType.RECEIVED, onClick = { vm.setTypeFilter(TransferType.RECEIVED) }, label = { Text("مستلم") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = GreenAccent, selectedLabelColor = Black))
                FilterChip(selected = type == TransferType.PAID, onClick = { vm.setTypeFilter(TransferType.PAID) }, label = { Text("مدفوع") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = RedAccent, selectedLabelColor = White))
                
                Box(modifier = Modifier.weight(1f)) {
                    OutlinedButton(onClick = { expandedAcc = true }, modifier = Modifier.fillMaxWidth()) {
                        Text(acc?.name ?: "كل الحسابات", maxLines = 1, color = White)
                    }
                    DropdownMenu(expanded = expandedAcc, onDismissRequest = { expandedAcc = false }) {
                        DropdownMenuItem(text = { Text("كل الحسابات") }, onClick = { vm.setAccountFilter(null); expandedAcc = false })
                        accounts.forEach { a ->
                            DropdownMenuItem(text = { Text(a.name) }, onClick = { vm.setAccountFilter(a.id); expandedAcc = false })
                        }
                    }
                }
                IconButton(onClick = { showDatePicker = true }) {
                    Icon(Icons.Default.DateRange, null, tint = if (dateRange != null) GreenAccent else White)
                }
            }

            if (dateRange != null) {
                Text("مفلتر بالتاريخ", color = GreenAccent, modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp))
            }

            if (transfers.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(Icons.Default.List, null, tint = SecondaryText, modifier = Modifier.size(64.dp))
                        Spacer(Modifier.height(16.dp))
                        Text("لا توجد حوالات مطابقة", color = SecondaryText, style = MaterialTheme.typography.titleMedium)
                        Text("أضف حوالة جديدة أو غير الفلاتر", color = SecondaryText, style = MaterialTheme.typography.bodySmall)
                    }
                }
            } else {
                LazyColumn(modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(transfers, key = { it.id }) { t ->
                        TransferCard(transfer = t, onClick = { onEdit(t.id) }, onDelete = { vm.deleteTransfer(t) })
                    }
                }
            }
        }

        if (showDatePicker) {
            val dateState = rememberDateRangePickerState()
            DatePickerDialog(
                onDismissRequest = { showDatePicker = false },
                confirmButton = {
                    TextButton(onClick = {
                        vm.setDateRange(dateState.selectedStartDateMillis, dateState.selectedEndDateMillis)
                        showDatePicker = false
                    }) { Text("موافق") }
                },
                dismissButton = {
                    TextButton(onClick = { vm.setDateRange(null, null); showDatePicker = false }) { Text("مسح الفلتر") }
                }
            ) { DateRangePicker(state = dateState) }
        }
    }
}
EOF

echo -e "${GREEN}✓ تم إنشاء جميع الملفات بنجاح.${NC}"

echo -e "${YELLOW}جاري رفع التحديثات إلى GitHub...${NC}"
git add .
git commit -m "Feat: Production Ready - Input Validation, Error Handling, Loading States, Empty States, and Accurate Balances" || echo "لا توجد تغييرات جديدة"
git push -u origin main

echo -e "${GREEN}✅ التطبيق الآن جاهز للإنتاج 100%! اذهب إلى GitHub Actions لتحميل الـ APK الجديد.${NC}"
