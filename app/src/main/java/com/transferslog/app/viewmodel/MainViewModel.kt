package com.transferslog.app.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.transferslog.app.data.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

class MainViewModel(private val repo: Repository) : ViewModel() {
    val accounts = repo.accounts.stateIn(viewModelScope, SharingStarted.Lazily, emptyList())
    val transfers = repo.transfers.stateIn(viewModelScope, SharingStarted.Lazily, emptyList())
    val savedNames = repo.savedNames.stateIn(viewModelScope, SharingStarted.Lazily, emptyList())

    fun saveTransfer(t: Transfer, done: () -> Unit) {
        viewModelScope.launch {
            if (t.id == 0) {
                val num = if (t.type == TransferType.PAID) (repo.maxPaidNumber() ?: 0) + 1 else null
                repo.addTransfer(t.copy(paidNumber = num))
            } else {
                repo.updateTransfer(t)
            }
            repo.saveName(t.recipientName)
            done()
        }
    }

    fun deleteTransfer(t: Transfer) = viewModelScope.launch { repo.deleteTransfer(t) }

    fun addAccount(name: String, opening: Double, done: () -> Unit) = viewModelScope.launch {
        repo.addAccount(Account(name = name, openingBalance = opening))
        done()
    }

    fun updateAccount(a: Account) = viewModelScope.launch { repo.updateAccount(a) }

    fun deleteAccount(a: Account, done: (Boolean) -> Unit) = viewModelScope.launch {
        val cnt = repo.accountTransferCount(a.id)
        if (cnt > 0) done(false) else { repo.deleteAccount(a); done(true) }
    }

    fun forceDeleteAccount(a: Account) = viewModelScope.launch { repo.deleteAccount(a) }

    fun clearAll() = viewModelScope.launch {
        repo.clearAllTransfers()
        repo.clearAllNames()
        accounts.value.forEach { repo.deleteAccount(it) }
    }
}

data class Stats(val received: Double, val paid: Double, val commission: Double) {
    val profit get() = commission
}

class MainViewModelFactory(private val repo: Repository) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(c: Class<T>): T {
        @Suppress("UNCHECKED_CAST")
        return MainViewModel(repo) as T
    }
}
