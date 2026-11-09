package com.transferslog.app.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.transferslog.app.data.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject

class MainViewModel(
    private val repo: Repository,
    val settings: AppSettings
) : ViewModel() {
    val accounts = repo.accounts.stateIn(viewModelScope, SharingStarted.Lazily, emptyList())
    val transfers = repo.transfers.stateIn(viewModelScope, SharingStarted.Lazily, emptyList())
    val savedNames = repo.savedNames.stateIn(viewModelScope, SharingStarted.Lazily, emptyList())

    fun saveTransfer(t: Transfer, done: () -> Unit) {
        viewModelScope.launch {
            if (t.id == 0) {
                val num = if (t.type == TransferType.PAID) (repo.maxPaidNumber() ?: 0) + 1 else null
                repo.addTransfer(t.copy(paidNumber = num))
            } else {
                repo.updateTransfer(t)
            }
            repo.saveName(t.recipientName)
            done()
        }
    }

    fun deleteTransfer(t: Transfer) = viewModelScope.launch { repo.deleteTransfer(t) }

    fun addAccount(name: String, opening: Double, done: () -> Unit) = viewModelScope.launch {
        repo.addAccount(Account(name = name, openingBalance = opening))
        done()
    }

    fun updateAccount(a: Account) = viewModelScope.launch { repo.updateAccount(a) }

    fun deleteAccount(a: Account, done: (Boolean) -> Unit) = viewModelScope.launch {
        val cnt = repo.accountTransferCount(a.id)
        if (cnt > 0) done(false) else { repo.deleteAccount(a); done(true) }
    }

    fun forceDeleteAccount(a: Account) = viewModelScope.launch { repo.deleteAccount(a) }

    fun clearAll() = viewModelScope.launch {
        repo.clearAllTransfers()
        repo.clearAllNames()
        accounts.value.forEach { repo.deleteAccount(it) }
    }

    // ---------- النسخ الاحتياطي ----------
    fun exportBackup(callback: (String?) -> Unit) {
        viewModelScope.launch {
            try {
                val accs = repo.accounts.first()
                val txs = repo.transfers.first()
                val sns = repo.savedNames.first()
                val root = JSONObject()
                root.put("version", 1)
                root.put("exportedAt", System.currentTimeMillis())

                val accArr = JSONArray()
                accs.forEach { a ->
                    accArr.put(JSONObject().apply {
                        put("id", a.id); put("name", a.name)
                        put("openingBalance", a.openingBalance)
                        put("createdAt", a.createdAt)
                    })
                }
                root.put("accounts", accArr)

                val txArr = JSONArray()
                txs.forEach { t ->
                    txArr.put(JSONObject().apply {
                        put("id", t.id)
                        put("type", t.type.name)
                        put("recipientName", t.recipientName)
                        put("amount", t.amount)
                        put("commission", t.commission)
                        put("date", t.date)
                        put("accountId", t.accountId)
                        if (t.paidNumber != null) put("paidNumber", t.paidNumber) else put("paidNumber", JSONObject.NULL)
                        if (t.note != null) put("note", t.note) else put("note", JSONObject.NULL)
                        put("createdAt", t.createdAt)
                    })
                }
                root.put("transfers", txArr)

                val snArr = JSONArray()
                sns.forEach { sn ->
                    snArr.put(JSONObject().apply {
                        put("id", sn.id); put("name", sn.name); put("lastUsed", sn.lastUsed)
                    })
                }
                root.put("savedNames", snArr)
                callback(root.toString(2))
            } catch (e: Exception) { callback(null) }
        }
    }

    fun importBackup(json: String, callback: (Boolean) -> Unit) {
        viewModelScope.launch {
            try {
                val root = JSONObject(json)
                repo.clearAllTransfers()
                repo.clearAllNames()
                repo.accounts.first().forEach { repo.deleteAccount(it) }

                val accArr = root.getJSONArray("accounts")
                for (i in 0 until accArr.length()) {
                    val a = accArr.getJSONObject(i)
                    repo.addAccount(Account(
                        id = a.getInt("id"), name = a.getString("name"),
                        openingBalance = a.getDouble("openingBalance"),
                        createdAt = a.getLong("createdAt")
                    ))
                }
                val txArr = root.getJSONArray("transfers")
                for (i in 0 until txArr.length()) {
                    val t = txArr.getJSONObject(i)
                    repo.addTransfer(Transfer(
                        id = t.getInt("id"),
                        type = TransferType.valueOf(t.getString("type")),
                        recipientName = t.getString("recipientName"),
                        amount = t.getDouble("amount"),
                        commission = t.getDouble("commission"),
                        date = t.getLong("date"),
                        accountId = t.getInt("accountId"),
                        paidNumber = if (t.isNull("paidNumber")) null else t.getInt("paidNumber"),
                        note = if (t.isNull("note")) null else t.getString("note"),
                        createdAt = t.getLong("createdAt")
                    ))
                }
                if (root.has("savedNames")) {
                    val snArr = root.getJSONArray("savedNames")
                    for (i in 0 until snArr.length()) {
                        repo.saveName(snArr.getJSONObject(i).getString("name"))
                    }
                }
                callback(true)
            } catch (e: Exception) { callback(false) }
        }
    }
}

class MainViewModelFactory(
    private val repo: Repository,
    private val settings: AppSettings
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(c: Class<T>): T {
        @Suppress("UNCHECKED_CAST")
        return MainViewModel(repo, settings) as T
    }
}
