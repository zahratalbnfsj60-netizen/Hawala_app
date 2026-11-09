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
    val date: Long = System.currentTimeMillis(), val accountId: Long, val paidNumber: Long? = null,
    val isLoading: Boolean = false, val errorMessage: String? = null, val savedMessage: String? = null
)

class AddEditViewModel(private val repository: Repository, val initialAccountId: Long) : ViewModel() {
    private val _formState = MutableStateFlow(TransferFormState(accountId = initialAccountId))
    val formState = _formState.asStateFlow()
    val savedNames = repository.getSavedNames()

    fun loadTransfer(id: Long) {
        viewModelScope.launch {
            repository.transferDao.getById(id)?.let { t ->
                _formState.value = TransferFormState(t.id, t.type, t.recipientName, t.amount.toString(), t.commission.toString(), t.date, t.accountId, t.paidNumber)
            }
        }
    }

    fun updateType(type: TransferType) { _formState.value = _formState.value.copy(type = type) }
    fun updateRecipient(name: String) { _formState.value = _formState.value.copy(recipientName = name) }
    fun updateAmount(amount: String) { _formState.value = _formState.value.copy(amount = amount) }
    fun updateCommission(commission: String) { _formState.value = _formState.value.copy(commission = commission) }
    fun updateDate(date: Long) { _formState.value = _formState.value.copy(date = DateUtils.normalizeToUtcStartOfDay(date)) }

    fun save() {
        val state = _formState.value
        val amountVal = state.amount.toDoubleOrNull()
        if (state.recipientName.isBlank() || amountVal == null || amountVal <= 0.0) {
            _formState.value = state.copy(errorMessage = "يرجى تعبئة الحقول المطلوبة بشكل صحيح")
            return
        }
        val commVal = if (state.type == TransferType.PAID) state.commission.toDoubleOrNull() ?: 0.0 else 0.0

        viewModelScope.launch {
            _formState.value = _formState.value.copy(isLoading = true, errorMessage = null)
            try {
                if (state.id == null) {
                    repository.insertTransfer(Transfer(type = state.type, recipientName = state.recipientName, amount = amountVal, commission = commVal, date = state.date, accountId = state.accountId))
                    _formState.value = TransferFormState(accountId = initialAccountId, savedMessage = "تم حفظ الحوالة")
                } else {
                    repository.updateTransfer(Transfer(id = state.id, type = state.type, recipientName = state.recipientName, amount = amountVal, commission = commVal, date = state.date, accountId = state.accountId, paidNumber = state.paidNumber))
                    _formState.value = state.copy(isLoading = false, savedMessage = "تم تحديث الحوالة")
                }
            } catch (e: Exception) {
                _formState.value = _formState.value.copy(isLoading = false, errorMessage = "خطأ: ${e.message}")
            }
        }
    }

    fun delete() {
        val state = _formState.value
        if (state.id != null) {
            viewModelScope.launch {
                repository.transferDao.getById(state.id)?.let { repository.deleteTransfer(it) }
                _formState.value = state.copy(savedMessage = "تم حذف الحوالة")
            }
        }
    }
    fun clearForm() { _formState.value = TransferFormState(accountId = initialAccountId) }
    fun clearMessage() { _formState.value = _formState.value.copy(savedMessage = null, errorMessage = null) }
}
