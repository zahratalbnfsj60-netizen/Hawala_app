package com.transferslog.app.ui.viewmodel

import android.content.Context
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.transferslog.app.data.Repository
import com.transferslog.app.util.JsonBackup
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

val Context.dataStore by preferencesDataStore(name = "settings")

class SettingsViewModel(private val repo: Repository, private val context: Context) : ViewModel() {
    private object Keys {
        val CURRENCY = stringPreferencesKey("currency")
        val COMM_1 = doublePreferencesKey("c1")
        val COMM_2 = doublePreferencesKey("c2")
        val DEFAULT_COMM = doublePreferencesKey("dc")
    }
    val currency = context.dataStore.data.map { it[Keys.CURRENCY] ?: "ل.س" }
    val commission1 = context.dataStore.data.map { it[Keys.COMM_1] ?: 100.0 }
    val commission2 = context.dataStore.data.map { it[Keys.COMM_2] ?: 250.0 }
    val defaultCommission = context.dataStore.data.map { it[Keys.DEFAULT_COMM] ?: 100.0 }

    fun setCurrency(v: String) = viewModelScope.launch { context.dataStore.edit { it[Keys.CURRENCY] = v } }
    fun setComm1(v: Double) = viewModelScope.launch { context.dataStore.edit { it[Keys.COMM_1] = v } }
    fun setComm2(v: Double) = viewModelScope.launch { context.dataStore.edit { it[Keys.COMM_2] = v } }
    fun setDefaultComm(v: Double) = viewModelScope.launch { context.dataStore.edit { it[Keys.DEFAULT_COMM] = v } }
    
    fun deleteAll(onDone: () -> Unit) = viewModelScope.launch { repo.deleteAllData(); onDone() }

    fun exportData(onResult: (String?) -> Unit) {
        viewModelScope.launch {
            val json = JsonBackup.export(
                repo.accountDao.getAll().first(),
                repo.transferDao.getFiltered(null, null, "", null, null).first(),
                repo.savedNameDao.getAll().first()
            )
            onResult(json)
        }
    }

    fun importData(json: String, onDone: (Boolean) -> Unit) {
        viewModelScope.launch {
            try {
                val data = JsonBackup.import(json)
                if (data != null) {
                    repo.deleteAllData()
                    data.accounts.forEach { repo.insertAccount(it) }
                    data.transfers.forEach { repo.transferDao.insert(it) }
                    data.savedNames.forEach { repo.savedNameDao.insert(it) }
                    onDone(true)
                } else onDone(false)
            } catch (e: Exception) { onDone(false) }
        }
    }
}
