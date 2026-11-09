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
