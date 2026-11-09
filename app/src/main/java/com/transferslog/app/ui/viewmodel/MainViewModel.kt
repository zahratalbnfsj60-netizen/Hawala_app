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
