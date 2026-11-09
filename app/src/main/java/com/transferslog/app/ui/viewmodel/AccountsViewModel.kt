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
                repo.transferDao.getAll()
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
