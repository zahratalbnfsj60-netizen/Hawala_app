package com.transferslog.app.ui.viewmodel

import android.content.Context
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.transferslog.app.data.Repository
import com.transferslog.app.util.JsonBackup
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

val Context.dataStore by preferencesDataStore(name = "settings")

data class SettingsUiState(val isLoading: Boolean = false, val message: String? = null)

class SettingsViewModel(val repo: Repository, private val context: Context) : ViewModel() {
    private object Keys { val CURRENCY = stringPreferencesKey("currency"); val COMM_1 = doublePreferencesKey("c1"); val COMM_2 = doublePreferencesKey("c2") }
    val currency = context.dataStore.data.map { it[Keys.CURRENCY] ?: "ل.س" }
    val commission1 = context.dataStore.data.map { it[Keys.COMM_1] ?: 100.0 }
    val commission2 = context.dataStore.data.map { it[Keys.COMM_2] ?: 250.0 }
    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState = _uiState.asStateFlow()

    fun setCurrency(v: String) = viewModelScope.launch { context.dataStore.edit { it[Keys.CURRENCY] = v } }
    fun setComm1(v: Double) = viewModelScope.launch { context.dataStore.edit { it[Keys.COMM_1] = v } }
    fun setComm2(v: Double) = viewModelScope.launch { context.dataStore.edit { it[Keys.COMM_2] = v } }

    fun exportData(onResult: (String?) -> Unit) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                val json = JsonBackup.export(repo.accountDao.getAll().first(), repo.transferDao.getFiltered(-1, null, "", null, null).first(), repo.savedNameDao.getAll().first())
                _uiState.update { it.copy(isLoading = false, message = "تم تصدير البيانات") }; onResult(json)
            } catch (e: Exception) { _uiState.update { it.copy(isLoading = false, message = "فشل التصدير: ${e.message}") }; onResult(null) }
        }
    }

    fun importData(json: String, onDone: (Boolean) -> Unit) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                val data = JsonBackup.import(json)
                if (data != null) {
                    repo.deleteAllData()
                    data.accounts.forEach { repo.insertAccount(it) }
                    data.transfers.forEach { repo.transferDao.insert(it) }
                    data.savedNames.forEach { repo.savedNameDao.insert(it) }
                    _uiState.update { it.copy(isLoading = false, message = "تم استيراد البيانات بنجاح") }; onDone(true)
                } else { _uiState.update { it.copy(isLoading = false, message = "ملف غير صالح") }; onDone(false) }
            } catch (e: Exception) { _uiState.update { it.copy(isLoading = false, message = "فشل الاستيراد: ${e.message}") }; onDone(false) }
        }
    }

    fun deleteAll(onDone: () -> Unit) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try { repo.deleteAllData(); _uiState.update { it.copy(isLoading = false, message = "تم حذف جميع البيانات") }; onDone()
            } catch (e: Exception) { _uiState.update { it.copy(isLoading = false, message = "فشل الحذف: ${e.message}") } }
        }
    }
    fun clearMessage() { _uiState.update { it.copy(message = null) } }
}
