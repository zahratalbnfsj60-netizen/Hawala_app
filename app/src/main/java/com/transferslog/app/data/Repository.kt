package com.transferslog.app.data

import android.content.Context
import androidx.room.Room
import kotlinx.coroutines.flow.Flow

class Repository(context: Context) {
    private val db = Room.databaseBuilder(
        context.applicationContext,
        AppDatabase::class.java,
        "transfers_log.db"
    ).fallbackToDestructiveMigration().build()

    val accounts: Flow<List<Account>> = db.accountDao().getAll()
    val transfers: Flow<List<Transfer>> = db.transferDao().getAll()
    val savedNames: Flow<List<SavedName>> = db.savedNameDao().getAll()

    suspend fun addAccount(account: Account) = db.accountDao().insert(account)
    suspend fun updateAccount(account: Account) = db.accountDao().update(account)
    suspend fun deleteAccount(account: Account) = db.accountDao().delete(account)
    suspend fun accountTransferCount(accountId: Int) = db.accountDao().transferCount(accountId)

    suspend fun addTransfer(transfer: Transfer) = db.transferDao().insert(transfer)
    suspend fun updateTransfer(transfer: Transfer) = db.transferDao().update(transfer)
    suspend fun deleteTransfer(transfer: Transfer) = db.transferDao().delete(transfer)
    suspend fun maxPaidNumber() = db.transferDao().maxPaidNumber()

    suspend fun saveName(name: String) {
        db.savedNameDao().insert(SavedName(name = name, lastUsed = System.currentTimeMillis()))
    }

    suspend fun clearAllTransfers() = db.transferDao().deleteAll()
    suspend fun clearAllNames() = db.savedNameDao().deleteAll()
}
