package com.transferslog.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.transferslog.app.data.Account
import com.transferslog.app.data.Repository
import com.transferslog.app.data.TransferType
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class AccountWithBalance(val account: Account, val currentBalance: Double)

class AccountsViewModel(private val repo: Repository) : ViewModel() {
    val accountsWithBalance = combine(
        repo.getAccounts(),
        repo.getFilteredTransfers() // جلب كل الحوالات لحساب الأرصدة
    ) { accounts, transfers ->
        accounts.map { acc ->
            val received = transfers.filter { it.accountId == acc.id && it.type == TransferType.RECEIVED }.sumOf { it.amount }
            val paid = transfers.filter { it.accountId == acc.id && it.type == TransferType.PAID }.sumOf { it.amount }
            val commission = transfers.filter { it.accountId == acc.id && it.type == TransferType.PAID }.sumOf { it.commission }
            val current = acc.openingBalance + received - paid - commission
            AccountWithBalance(acc, current)
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun add(name: String, opening: Double) = viewModelScope.launch { repo.insertAccount(Account(name = name, openingBalance = opening)) }
    fun update(account: Account) = viewModelScope.launch { repo.updateAccount(account) }
    fun delete(account: Account) = viewModelScope.launch { repo.deleteAccount(account) }
}
