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
