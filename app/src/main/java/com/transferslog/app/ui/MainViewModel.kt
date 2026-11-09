package com.transferslog.app.ui
import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.transferslog.app.data.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
class MainViewModel(app: Application) : AndroidViewModel(app) {
    private val db = AppDatabase.get(app)
    private val repo = HawalaRepository(db.accountDao(), db.transferDao(), db.savedNameDao())
    val accounts = repo.accounts().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
    val accountsWithBalance = repo.accountsWithBalance().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
    val recentNames = repo.recentNames().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
    private val _selectedId = MutableStateFlow<Long?>(null)
    val selectedId: StateFlow<Long?> = _selectedId.asStateFlow()
    val selectedAccount: StateFlow<Account?> = _selectedId.flatMapLatest { id -> flow { emit(id?.let { repo.getAccount(it) }) } }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)
    val transfers: StateFlow<List<Transfer>> = _selectedId.flatMapLatest { id -> if (id == null) flowOf(emptyList()) else repo.transfers(id) }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
    private val _error = MutableSharedFlow<String>()
    val error = _error.asSharedFlow()
    fun selectAccount(id: Long) { _selectedId.value = id }
    fun insertAccount(name: String, openingBalance: Double, onDone: (Long) -> Unit = {}) {
        viewModelScope.launch {
            runCatching { repo.insertAccount(Account(name = name.trim(), openingBalance = openingBalance)) }
                .onSuccess { id -> _selectedId.value = id; onDone(id) }
                .onFailure { _error.emit("فشل الحفظ: \${it.message}") }
        }
    }
    fun updateAccount(a: Account) { viewModelScope.launch { runCatching { repo.updateAccount(a) }.onFailure { _error.emit("فشل التحديث: \${it.message}") } } }
    fun deleteAccount(a: Account) { viewModelScope.launch { runCatching { repo.deleteAccount(a); if (_selectedId.value == a.id) _selectedId.value = null }.onFailure { _error.emit("فشل الحذف: \${it.message}") } } }
    fun saveTransfer(existing: Transfer?, type: String, name: String, amount: Double, commission: Double, date: Long, onDone: () -> Unit) {
        val accId = _selectedId.value ?: return
        viewModelScope.launch {
            runCatching {
                repo.rememberName(name.trim())
                if (existing == null) {
                    val paidNumber = if (type == TransferType.PAID) repo.maxPaidNumber(accId) + 1 else 0
                    repo.insertTransfer(Transfer(type = type, recipientName = name.trim(), amount = amount, commission = if (type == TransferType.PAID) commission else 0.0, date = date, accountId = accId, paidNumber = paidNumber))
                } else {
                    val newPaid = when {
                        type == TransferType.PAID && existing.type == TransferType.PAID -> existing.paidNumber
                        type == TransferType.PAID -> repo.maxPaidNumber(accId) + 1
                        else -> 0
                    }
                    repo.updateTransfer(existing.copy(type = type, recipientName = name.trim(), amount = amount, commission = if (type == TransferType.PAID) commission else 0.0, date = date, paidNumber = newPaid))
                }
                onDone()
            }.onFailure { _error.emit("فشل الحفظ: \${it.message}") }
        }
    }
    fun deleteTransfer(t: Transfer) { viewModelScope.launch { runCatching { repo.deleteTransfer(t) }.onFailure { _error.emit("فشل الحذف: \${it.message}") } } }
    suspend fun getTransfer(id: Long): Transfer? = repo.getTransfer(id)
    suspend fun transfersInRange(accId: Long, from: Long, to: Long) = repo.transfersInRange(accId, from, to)
    suspend fun wipeAll() = repo.wipeAll()
}
