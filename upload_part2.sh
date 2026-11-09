#!/data/data/com.termux/files/usr/bin/bash
set -e
DIR="$HOME/Hawala_app"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
cd "$DIR"

echo -e "${YELLOW}جاري إنشاء ملفات Kotlin...${NC}"

# ===== MainActivity =====
cat > app/src/main/java/com/transferslog/app/MainActivity.kt <<'EOF'
package com.transferslog.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import com.transferslog.app.data.AppDatabase
import com.transferslog.app.data.Repository
import com.transferslog.app.ui.navigation.AppNavigation
import com.transferslog.app.ui.theme.TransfersLogTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val database = AppDatabase.getDatabase(applicationContext)
        val repository = Repository(database)
        setContent {
            TransfersLogTheme {
                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                    Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                        AppNavigation(repository)
                    }
                }
            }
        }
    }
}
EOF

# ===== Data Layer =====
cat > app/src/main/java/com/transferslog/app/data/Entities.kt <<'EOF'
package com.transferslog.app.data

import androidx.room.Entity
import androidx.room.PrimaryKey

enum class TransferType { PAID, RECEIVED }

@Entity(tableName = "accounts")
data class Account(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val openingBalance: Double = 0.0,
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "transfers")
data class Transfer(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val type: TransferType,
    val recipientName: String,
    val amount: Double,
    val commission: Double = 0.0,
    val date: Long,
    val accountId: Long,
    val paidNumber: Long? = null,
    val note: String? = null,
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "saved_names")
data class SavedName(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val lastUsed: Long = System.currentTimeMillis()
)
EOF

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
        WHERE (:accountId IS NULL OR accountId = :accountId)
        AND (:type IS NULL OR type = :type)
        AND (:searchQuery = '' OR recipientName LIKE '%' || :searchQuery || '%' OR CAST(amount AS TEXT) LIKE '%' || :searchQuery || '%')
        AND (:startDate IS NULL OR date >= :startDate)
        AND (:endDate IS NULL OR date <= :endDate)
        ORDER BY date DESC, createdAt DESC
    """)
    fun getFiltered(
        accountId: Long?,
        type: TransferType?,
        searchQuery: String,
        startDate: Long?,
        endDate: Long?
    ): Flow<List<Transfer>>

    @Query("SELECT * FROM transfers WHERE id = :id")
    suspend fun getById(id: Long): Transfer?

    @Insert
    suspend fun insert(transfer: Transfer): Long

    @Update
    suspend fun update(transfer: Transfer)

    @Delete
    suspend fun delete(transfer: Transfer)

    @Query("SELECT MAX(paidNumber) FROM transfers WHERE type = 'PAID'")
    suspend fun getMaxPaidNumber(): Long?

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

cat > app/src/main/java/com/transferslog/app/data/AppDatabase.kt <<'EOF'
package com.transferslog.app.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverter
import androidx.room.TypeConverters

class Converters {
    @TypeConverter fun fromTransferType(type: TransferType): String = type.name
    @TypeConverter fun toTransferType(value: String): TransferType = TransferType.valueOf(value)
}

@Database(entities = [Account::class, Transfer::class, SavedName::class], version = 1, exportSchema = false)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun accountDao(): AccountDao
    abstract fun transferDao(): TransferDao
    abstract fun savedNameDao(): SavedNameDao

    companion object {
        @Volatile private var INSTANCE: AppDatabase? = null
        fun getDatabase(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(context.applicationContext, AppDatabase::class.java, "transfers_log_database").build()
                INSTANCE = instance
                instance
            }
        }
    }
}
EOF

cat > app/src/main/java/com/transferslog/app/data/Repository.kt <<'EOF'
package com.transferslog.app.data

import kotlinx.coroutines.flow.Flow

class Repository(private val database: AppDatabase) {
    val accountDao = database.accountDao()
    val transferDao = database.transferDao()
    val savedNameDao = database.savedNameDao()

    fun getAccounts(): Flow<List<Account>> = accountDao.getAll()

    fun getFilteredTransfers(
        accountId: Long? = null,
        type: TransferType? = null,
        searchQuery: String = "",
        startDate: Long? = null,
        endDate: Long? = null
    ): Flow<List<Transfer>> = transferDao.getFiltered(accountId, type, searchQuery, startDate, endDate)

    suspend fun insertAccount(account: Account) = accountDao.insert(account)
    suspend fun updateAccount(account: Account) = accountDao.update(account)
    suspend fun deleteAccount(account: Account) {
        transferDao.deleteByAccountId(account.id)
        accountDao.delete(account)
    }

    suspend fun insertTransfer(transfer: Transfer): Long {
        val nextPaidNumber = if (transfer.type == TransferType.PAID) {
            (transferDao.getMaxPaidNumber() ?: 0) + 1
        } else null
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

# ===== Utils =====
cat > app/src/main/java/com/transferslog/app/util/DateUtils.kt <<'EOF'
package com.transferslog.app.util

import java.util.Calendar
import java.util.TimeZone

object DateUtils {
    fun normalizeToUtcStartOfDay(timestamp: Long): Long {
        val cal = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            timeInMillis = timestamp
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        return cal.timeInMillis
    }
}
EOF

cat > app/src/main/java/com/transferslog/app/util/JsonBackup.kt <<'EOF'
package com.transferslog.app.util

import com.google.gson.Gson
import com.transferslog.app.data.*

data class BackupData(val accounts: List<Account>, val transfers: List<Transfer>, val savedNames: List<SavedName>)

object JsonBackup {
    private val gson = Gson()
    fun export(accounts: List<Account>, transfers: List<Transfer>, savedNames: List<SavedName>): String =
        gson.toJson(BackupData(accounts, transfers, savedNames))
    fun import(json: String): BackupData? = try { gson.fromJson(json, BackupData::class.java) } catch (e: Exception) { null }
}
EOF

# ===== Theme =====
cat > app/src/main/java/com/transferslog/app/ui/theme/Theme.kt <<'EOF'
package com.transferslog.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.sp

val Black = Color(0xFF000000)
val DarkGray = Color(0xFF161616)
val LightGray = Color(0xFF1F1F1F)
val White = Color(0xFFFFFFFF)
val SecondaryText = Color(0xFF9E9E9E)
val GreenAccent = Color(0xFF00C853)
val RedAccent = Color(0xFFE53935)

private val DarkColorScheme = darkColorScheme(
    primary = GreenAccent, secondary = RedAccent, background = Black, surface = DarkGray,
    onPrimary = Black, onSecondary = White, onBackground = White, onSurface = White
)

val AppTypography = Typography(bodyLarge = TextStyle(fontFamily = FontFamily.Default, fontSize = 16.sp))

@Composable
fun TransfersLogTheme(darkTheme: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = DarkColorScheme, typography = AppTypography, content = content)
}
EOF

# ===== ViewModels =====
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
    private val _dateRange = MutableStateFlow<Pair<Long?, Long?>?>(null)
    val dateRange = _dateRange.asStateFlow()

    val accounts = repository.getAccounts().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    @OptIn(ExperimentalCoroutinesApi::class)
    val transfers = combine(_searchQuery, _selectedType, _selectedAccountId, _dateRange) { q, t, a, d ->
        FilterParams(q, t, a, d)
    }.flatMapLatest { p ->
        repository.getFilteredTransfers(p.accountId, p.type, p.query, p.dateRange?.first, p.dateRange?.second)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun setSearchQuery(query: String) { _searchQuery.value = query }
    fun setTypeFilter(type: TransferType?) { _selectedType.value = type }
    fun setAccountFilter(accountId: Long?) { _selectedAccountId.value = accountId }
    fun setDateRange(start: Long?, end: Long?) { _dateRange.value = start to end }
    fun deleteTransfer(transfer: Transfer) { viewModelScope.launch { repository.deleteTransfer(transfer) } }

    private data class FilterParams(val query: String, val type: TransferType?, val accountId: Long?, val dateRange: Pair<Long?, Long?>?)
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
    val date: Long = System.currentTimeMillis(), val accountId: Long? = null,
    val note: String = "", val paidNumber: Long? = null,
    val savedMessage: String? = null, val hasChanges: Boolean = false
)

class AddEditViewModel(private val repository: Repository) : ViewModel() {
    private val _formState = MutableStateFlow(TransferFormState())
    val formState = _formState.asStateFlow()
    val accounts = repository.getAccounts()
    val savedNames = repository.getSavedNames()

    fun loadTransfer(id: Long) {
        viewModelScope.launch {
            repository.transferDao.getById(id)?.let { t ->
                _formState.value = TransferFormState(
                    id = t.id, type = t.type, recipientName = t.recipientName, amount = t.amount.toString(),
                    commission = t.commission.toString(), date = t.date, accountId = t.accountId,
                    note = t.note ?: "", paidNumber = t.paidNumber
                )
            }
        }
    }

    fun updateType(type: TransferType) { _formState.value = _formState.value.copy(type = type, hasChanges = true) }
    fun updateRecipient(name: String) { _formState.value = _formState.value.copy(recipientName = name, hasChanges = true) }
    fun updateAmount(amount: String) { _formState.value = _formState.value.copy(amount = amount, hasChanges = true) }
    fun updateCommission(commission: String) { _formState.value = _formState.value.copy(commission = commission, hasChanges = true) }
    fun updateDate(date: Long) { _formState.value = _formState.value.copy(date = DateUtils.normalizeToUtcStartOfDay(date), hasChanges = true) }
    fun updateAccount(id: Long?) { _formState.value = _formState.value.copy(accountId = id, hasChanges = true) }
    fun updateNote(note: String) { _formState.value = _formState.value.copy(note = note, hasChanges = true) }

    fun save() {
        val state = _formState.value
        val amount = state.amount.toDoubleOrNull() ?: return
        val commission = if (state.type == TransferType.PAID) state.commission.toDoubleOrNull() ?: 0.0 else 0.0
        viewModelScope.launch {
            if (state.id == null) {
                repository.insertTransfer(Transfer(type = state.type, recipientName = state.recipientName, amount = amount, commission = commission, date = state.date, accountId = state.accountId ?: return@launch, note = state.note.ifBlank { null }))
                _formState.value = TransferFormState(savedMessage = "تم الحفظ")
            } else {
                repository.updateTransfer(Transfer(id = state.id, type = state.type, recipientName = state.recipientName, amount = amount, commission = commission, date = state.date, accountId = state.accountId ?: return@launch, note = state.note.ifBlank { null }, paidNumber = state.paidNumber))
                _formState.value = state.copy(savedMessage = "تم التحديث", hasChanges = false)
            }
        }
    }
    fun clearForm() { _formState.value = TransferFormState() }
    fun clearMessage() { _formState.value = _formState.value.copy(savedMessage = null) }
}
EOF

cat > app/src/main/java/com/transferslog/app/ui/viewmodel/AccountsViewModel.kt <<'EOF'
package com.transferslog.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.transferslog.app.data.Account
import com.transferslog.app.data.Repository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class AccountsViewModel(private val repo: Repository) : ViewModel() {
    val accounts = repo.getAccounts().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
    fun add(name: String, opening: Double) = viewModelScope.launch { repo.insertAccount(Account(name = name, openingBalance = opening)) }
    fun update(account: Account) = viewModelScope.launch { repo.updateAccount(account) }
    fun delete(account: Account) = viewModelScope.launch { repo.deleteAccount(account) }
}
EOF

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
            val opening = accounts.value.find { it.id == _selectedAccountId.value }?.openingBalance ?: 0.0
            val r = list.filter { it.type == TransferType.RECEIVED }.sumOf { it.amount }
            val p = list.filter { it.type == TransferType.PAID }.sumOf { it.amount }
            val c = list.filter { it.type == TransferType.PAID }.sumOf { it.commission }
            StatisticsData(opening, r, p, c, opening + r - p - c)
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), StatisticsData())

    fun selectAccount(id: Long?) { _selectedAccountId.value = id }
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
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

val Context.dataStore by preferencesDataStore(name = "settings")

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

    fun setCurrency(v: String) = viewModelScope.launch { context.dataStore.edit { it[Keys.CURRENCY] = v } }
    fun setComm1(v: Double) = viewModelScope.launch { context.dataStore.edit { it[Keys.COMM_1] = v } }
    fun setComm2(v: Double) = viewModelScope.launch { context.dataStore.edit { it[Keys.COMM_2] = v } }
    fun setDefaultComm(v: Double) = viewModelScope.launch { context.dataStore.edit { it[Keys.DEFAULT_COMM] = v } }
    fun deleteAll(onDone: () -> Unit) = viewModelScope.launch { repo.deleteAllData(); onDone() }
}
EOF

# ===== Components =====
cat > app/src/main/java/com/transferslog/app/ui/components/TransferCard.kt <<'EOF'
package com.transferslog.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.transferslog.app.data.Transfer
import com.transferslog.app.data.TransferType
import com.transferslog.app.ui.theme.*
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TransferCard(transfer: Transfer, onClick: () -> Unit, onDelete: () -> Unit) {
    val borderColor = if (transfer.type == TransferType.RECEIVED) GreenAccent else RedAccent
    val dismissState = rememberSwipeToDismissBoxState(confirmValueChange = {
        if (it == SwipeToDismissBoxValue.EndToStart) { onDelete(); true } else false
    })

    SwipeToDismissBox(
        state = dismissState,
        backgroundContent = {
            Box(modifier = Modifier.fillMaxSize().background(RedAccent, RoundedCornerShape(8.dp)).padding(16.dp), contentAlignment = Alignment.CenterEnd) {
                Text("حذف", color = White, fontWeight = FontWeight.Bold)
            }
        }
    ) {
        Card(
            onClick = onClick,
            modifier = Modifier.fillMaxWidth().border(1.dp, borderColor, RoundedCornerShape(8.dp)),
            shape = RoundedCornerShape(8.dp),
            colors = CardDefaults.cardColors(containerColor = LightGray)
        ) {
            Row(modifier = Modifier.padding(12.dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Column {
                    Text(transfer.recipientName, color = White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    Text(SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date(transfer.date)), color = SecondaryText, fontSize = 12.sp)
                    transfer.note?.let { Text(it, color = SecondaryText, fontSize = 12.sp) }
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text("${transfer.amount} ل.س", color = borderColor, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    if (transfer.type == TransferType.PAID && transfer.paidNumber != null) {
                        Text("رقم: ${transfer.paidNumber}", color = SecondaryText, fontSize = 12.sp)
                    }
                }
            }
        }
    }
}
EOF

cat > app/src/main/java/com/transferslog/app/ui/components/StatBar.kt <<'EOF'
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
EOF

# ===== Screens =====
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
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
    val acc = accounts.find { it.id == accId }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("سجل الحوالات", color = White) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Black),
                actions = {
                    IconButton(onClick = onNavAcc) { Icon(Icons.Default.AccountBalance, null, tint = White) }
                    IconButton(onClick = onNavStats) { Icon(Icons.Default.BarChart, null, tint = White) }
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
                placeholder = { Text("بحث...", color = SecondaryText) },
                leadingIcon = { Icon(Icons.Default.Search, null, tint = SecondaryText) },
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = GreenAccent, unfocusedBorderColor = LightGray, focusedTextColor = White, unfocusedTextColor = White),
                singleLine = true
            )
            Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = type == null, onClick = { vm.setTypeFilter(null) }, label = { Text("الكل") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = GreenAccent, selectedLabelColor = Black))
                FilterChip(selected = type == TransferType.RECEIVED, onClick = { vm.setTypeFilter(TransferType.RECEIVED) }, label = { Text("مستلم") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = GreenAccent, selectedLabelColor = Black))
                FilterChip(selected = type == TransferType.PAID, onClick = { vm.setTypeFilter(TransferType.PAID) }, label = { Text("مدفوع") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = RedAccent, selectedLabelColor = White))
            }
            LazyColumn(modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(transfers, key = { it.id }) { t ->
                    TransferCard(transfer = t, onClick = { onEdit(t.id) }, onDelete = { vm.deleteTransfer(t) })
                }
            }
        }
    }
}
EOF

cat > app/src/main/java/com/transferslog/app/ui/screens/AddEditTransferScreen.kt <<'EOF'
package com.transferslog.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
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
    val accounts by vm.accounts.collectAsState()
    val savedNames by vm.savedNames.collectAsState()
    val snackbar = remember { SnackbarHostState() }
    var showDatePicker by remember { mutableStateOf(false) }

    LaunchedEffect(id) { id?.let { vm.loadTransfer(it) } }
    LaunchedEffect(state.savedMessage) {
        state.savedMessage?.let {
            snackbar.showSnackbar(it); vm.clearMessage()
            if (state.id != null) onBack()
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = { Text(if (state.id == null) "إضافة حوالة" else "تعديل حوالة") },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, null) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Black, titleContentColor = White, navigationIconContentColor = White)
            )
        },
        bottomBar = {
            Row(modifier = Modifier.fillMaxWidth().background(DarkGray).padding(8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = { vm.save() }, modifier = Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = GreenAccent)) { Text("حفظ", color = Black) }
                OutlinedButton(onClick = { vm.clearForm() }, modifier = Modifier.weight(1f)) { Text("إلغاء") }
            }
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize().background(Black).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = state.type == TransferType.RECEIVED, onClick = { vm.updateType(TransferType.RECEIVED) }, label = { Text("مستلم") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = GreenAccent, selectedLabelColor = Black))
                FilterChip(selected = state.type == TransferType.PAID, onClick = { vm.updateType(TransferType.PAID) }, label = { Text("مدفوع") }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = RedAccent, selectedLabelColor = White))
            }

            OutlinedTextField(value = state.recipientName, onValueChange = vm::updateRecipient, label = { Text("اسم المستلم") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))
            OutlinedTextField(value = state.amount, onValueChange = vm::updateAmount, label = { Text("المبلغ") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))

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
    }
}
EOF

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
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.transferslog.app.data.Account
import com.transferslog.app.ui.theme.*
import com.transferslog.app.ui.viewmodel.AccountsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountsScreen(vm: AccountsViewModel, onBack: () -> Unit) {
    val accounts by vm.accounts.collectAsState()
    var showDialog by remember { mutableStateOf(false) }
    var name by remember { mutableStateOf("") }
    var opening by remember { mutableStateOf("") }

    Scaffold(
        topBar = { TopAppBar(title = { Text("الحسابات") }, navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, null) } }, colors = TopAppBarDefaults.topAppBarColors(containerColor = Black, titleContentColor = White, navigationIconContentColor = White)) },
        floatingActionButton = { FloatingActionButton(onClick = { showDialog = true }, containerColor = GreenAccent) { Icon(Icons.Default.Add, null, tint = Black) } }
    ) { padding ->
        LazyColumn(modifier = Modifier.padding(padding).fillMaxSize().background(Black), contentPadding = PaddingValues(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(accounts, key = { it.id }) { acc ->
                Card(colors = CardDefaults.cardColors(containerColor = LightGray), modifier = Modifier.fillMaxWidth()) {
                    Row(modifier = Modifier.padding(16.dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Column {
                            Text(acc.name, color = White)
                            Text("افتتاحي: ${acc.openingBalance}", color = SecondaryText)
                        }
                        IconButton(onClick = { vm.delete(acc) }) { Icon(Icons.Default.Delete, null, tint = RedAccent) }
                    }
                }
            }
        }
        if (showDialog) {
            AlertDialog(
                onDismissRequest = { showDialog = false },
                title = { Text("إضافة حساب") },
                text = {
                    Column {
                        OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("الاسم") })
                        OutlinedTextField(value = opening, onValueChange = { opening = it }, label = { Text("الرصيد الافتتاحي") })
                    }
                },
                confirmButton = { TextButton(onClick = { vm.add(name, opening.toDoubleOrNull() ?: 0.0); showDialog = false; name = ""; opening = "" }) { Text("حفظ") } },
                dismissButton = { TextButton(onClick = { showDialog = false }) { Text("إلغاء") } }
            )
        }
    }
}
EOF

cat > app/src/main/java/com/transferslog/app/ui/screens/StatisticsScreen.kt <<'EOF'
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
EOF

cat > app/src/main/java/com/transferslog/app/ui/screens/SettingsScreen.kt <<'EOF'
package com.transferslog.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.transferslog.app.ui.theme.*
import com.transferslog.app.ui.viewmodel.SettingsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(vm: SettingsViewModel, onBack: () -> Unit) {
    val currency by vm.currency.collectAsState(initial = "ل.س")
    val c1 by vm.commission1.collectAsState(initial = 100.0)
    val c2 by vm.commission2.collectAsState(initial = 250.0)
    var showDeleteConfirm by remember { mutableStateOf(false) }

    Scaffold(
        topBar = { TopAppBar(title = { Text("الإعدادات") }, navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, null) } }, colors = TopAppBarDefaults.topAppBarColors(containerColor = Black, titleContentColor = White, navigationIconContentColor = White)) }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize().background(Black).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            OutlinedTextField(value = currency, onValueChange = { vm.setCurrency(it) }, label = { Text("العملة") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))
            OutlinedTextField(value = c1.toString(), onValueChange = { it.toDoubleOrNull()?.let { v -> vm.setComm1(v) } }, label = { Text("العمولة الأولى") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))
            OutlinedTextField(value = c2.toString(), onValueChange = { it.toDoubleOrNull()?.let { v -> vm.setComm2(v) } }, label = { Text("العمولة الثانية") }, modifier = Modifier.fillMaxWidth(), colors = OutlinedTextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White))
            
            Button(onClick = { showDeleteConfirm = true }, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = RedAccent)) {
                Text("حذف كل البيانات")
            }

            Divider(color = LightGray)
            Text("عن البرنامج", color = White, style = MaterialTheme.typography.titleLarge)
            Text("الإصدار: 1.0", color = SecondaryText)
            Text("المبرمج: أدهم الهبة", color = SecondaryText)
        }

        if (showDeleteConfirm) {
            AlertDialog(
                onDismissRequest = { showDeleteConfirm = false },
                title = { Text("تأكيد الحذف") },
                text = { Text("هل أنت متأكد من حذف جميع البيانات نهائياً؟") },
                confirmButton = { TextButton(onClick = { vm.deleteAll { showDeleteConfirm = false } }) { Text("نعم، احذف", color = RedAccent) } },
                dismissButton = { TextButton(onClick = { showDeleteConfirm = false }) { Text("إلغاء") } }
            )
        }
    }
}
EOF

# ===== Navigation =====
cat > app/src/main/java/com/transferslog/app/ui/navigation/AppNavigation.kt <<'EOF'
package com.transferslog.app.ui.navigation

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
    NavHost(navController = nav, startDestination = "home") {
        composable("home") {
            val vm: MainViewModel = viewModel { MainViewModel(repo) }
            HomeScreen(vm,
                onAdd = { nav.navigate("add_edit?type=${it.name}") },
                onEdit = { nav.navigate("add_edit?id=$it") },
                onNavAcc = { nav.navigate("accounts") },
                onNavStats = { nav.navigate("stats") },
                onNavSettings = { nav.navigate("settings") }
            )
        }
        composable("add_edit?id={id}&type={type}", arguments = listOf(
            navArgument("id") { type = NavType.LongType; defaultValue = -1L },
            navArgument("type") { type = NavType.StringType; defaultValue = TransferType.RECEIVED.name }
        )) { backStack ->
            val id = backStack.arguments?.getLong("id")?.takeIf { it > 0 }
            val vm: AddEditViewModel = viewModel { AddEditViewModel(repo) }
            AddEditTransferScreen(vm, id) { nav.popBackStack() }
        }
        composable("accounts") {
            val vm: AccountsViewModel = viewModel { AccountsViewModel(repo) }
            AccountsScreen(vm) { nav.popBackStack() }
        }
        composable("stats") {
            val vm: StatisticsViewModel = viewModel { StatisticsViewModel(repo) }
            StatisticsScreen(vm) { nav.popBackStack() }
        }
        composable("settings") {
            val ctx = LocalContext.current
            val vm: SettingsViewModel = viewModel { SettingsViewModel(repo, ctx) }
            SettingsScreen(vm) { nav.popBackStack() }
        }
    }
}
EOF

echo -e "${GREEN}✓ تم إنشاء جميع ملفات Kotlin بنجاح${NC}"

# ===== Git Push =====
echo -e "${YELLOW}جاري رفع الكود إلى GitHub...${NC}"
git add .
git commit -m "Complete App: UI, DB, ViewModels, and Screens" || echo "لا توجد تغييرات جديدة"
git push -u origin main

echo -e "${GREEN}✅ تمت العملية بنجاح! اذهب إلى GitHub Actions لترى الـ APK يُبنى الآن.${NC}"
