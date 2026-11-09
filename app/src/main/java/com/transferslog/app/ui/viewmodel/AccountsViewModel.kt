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
