package com.transferslog.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.transferslog.app.data.*
import com.transferslog.app.util.DateUtils
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class TransferFormState(
    val id: Long? = null,
    val type: TransferType = TransferType.RECEIVED,
    val recipientName: String = "",
    val amount: String = "",
    val commission: String = "",
    val date: Long = System.currentTimeMillis(),
    val accountId: Long? = null,
    val note: String = "",
    val paidNumber: Long? = null,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val savedMessage: String? = null,
    val hasChanges: Boolean = false,
    val nameError: Boolean = false,
    val amountError: Boolean = false,
    val accountError: Boolean = false
)

class AddEditViewModel(private val repository: Repository) : ViewModel() {
    private val _formState = MutableStateFlow(TransferFormState())
    val formState = _formState.asStateFlow()

    val accounts = repository.getAccounts()
    val savedNames = repository.getSavedNames()

    fun loadTransfer(id: Long) {
        viewModelScope.launch {
            _formState.value = _formState.value.copy(isLoading = true)
            try {
                repository.transferDao.getById(id)?.let { t ->
                    _formState.value = TransferFormState(
                        id = t.id, type = t.type, recipientName = t.recipientName, amount = t.amount.toString(),
                        commission = t.commission.toString(), date = t.date, accountId = t.accountId,
                        note = t.note ?: "", paidNumber = t.paidNumber, isLoading = false
                    )
                }
            } catch (e: Exception) {
                _formState.value = _formState.value.copy(isLoading = false, errorMessage = "فشل تحميل الحوالة: ${e.message}")
            }
        }
    }

    fun updateType(type: TransferType) { _formState.value = _formState.value.copy(type = type, hasChanges = true) }
    fun updateRecipient(name: String) { _formState.value = _formState.value.copy(recipientName = name, hasChanges = true, nameError = false) }
    fun updateAmount(amount: String) { _formState.value = _formState.value.copy(amount = amount, hasChanges = true, amountError = false) }
    fun updateCommission(commission: String) { _formState.value = _formState.value.copy(commission = commission, hasChanges = true) }
    fun updateDate(date: Long) { _formState.value = _formState.value.copy(date = DateUtils.normalizeToUtcStartOfDay(date), hasChanges = true) }
    fun updateAccount(id: Long?) { _formState.value = _formState.value.copy(accountId = id, hasChanges = true, accountError = false) }
    fun updateNote(note: String) { _formState.value = _formState.value.copy(note = note, hasChanges = true) }

    fun save() {
        val state = _formState.value
        val nameValid = state.recipientName.isNotBlank()
        val amountVal = state.amount.toDoubleOrNull()
        val amountValid = amountVal != null && amountVal > 0
        val accountValid = state.accountId != null
        val commVal = if (state.type == TransferType.PAID) state.commission.toDoubleOrNull() ?: 0.0 else 0.0

        if (!nameValid || !amountValid || !accountValid) {
            _formState.value = state.copy(
                nameError = !nameValid,
                amountError = !amountValid,
                accountError = !accountValid,
                errorMessage = "يرجى تصحيح الحقول المطلوبة"
            )
            return
        }

        viewModelScope.launch {
            _formState.value = _formState.value.copy(isLoading = true, errorMessage = null)
            try {
                if (state.id == null) {
                    repository.insertTransfer(Transfer(
                        type = state.type, recipientName = state.recipientName, amount = amountVal!!,
                        commission = commVal, date = state.date, accountId = state.accountId!!,
                        note = state.note.ifBlank { null }
                    ))
                    _formState.value = TransferFormState(savedMessage = "تم حفظ الحوالة بنجاح")
                } else {
                    repository.updateTransfer(Transfer(
                        id = state.id, type = state.type, recipientName = state.recipientName, amount = amountVal!!,
                        commission = commVal, date = state.date, accountId = state.accountId!!,
                        note = state.note.ifBlank { null }, paidNumber = state.paidNumber
                    ))
                    _formState.value = state.copy(isLoading = false, savedMessage = "تم تحديث الحوالة بنجاح", hasChanges = false)
                }
            } catch (e: Exception) {
                _formState.value = _formState.value.copy(isLoading = false, errorMessage = "حدث خطأ أثناء الحفظ: ${e.message}")
            }
        }
    }

    fun clearForm() { _formState.value = TransferFormState() }
    fun clearMessage() { _formState.value = _formState.value.copy(savedMessage = null, errorMessage = null) }
}
