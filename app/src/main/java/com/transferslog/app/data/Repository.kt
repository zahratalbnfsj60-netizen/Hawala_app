package com.transferslog.app.data

import kotlinx.coroutines.flow.Flow

class Repository(val database: AppDatabase) {
    val accountDao = database.accountDao()
    val transferDao = database.transferDao()
    val savedNameDao = database.savedNameDao()

    fun getAccounts(): Flow<List<Account>> = accountDao.getAll()
    fun getFilteredTransfers(accountId: Long, type: TransferType? = null, searchQuery: String = "", startDate: Long? = null, endDate: Long? = null): Flow<List<Transfer>> = transferDao.getFiltered(accountId, type, searchQuery, startDate, endDate)

    suspend fun insertAccount(account: Account) = accountDao.insert(account)
    suspend fun updateAccount(account: Account) = accountDao.update(account)
    suspend fun deleteAccount(account: Account) {
        transferDao.deleteByAccountId(account.id)
        accountDao.delete(account)
    }

    suspend fun insertTransfer(transfer: Transfer): Long {
        val nextPaidNumber = if (transfer.type == TransferType.PAID) (transferDao.getMaxPaidNumber(transfer.accountId) ?: 0) + 1 else null
        val id = transferDao.insert(transfer.copy(paidNumber = nextPaidNumber))
        savedNameDao.insert(SavedName(name = transfer.recipientName, lastUsed = System.currentTimeMillis()))
        return id
    }

    suspend fun updateTransfer(transfer: Transfer) {
        transferDao.update(transfer)
        savedNameDao.insert(SavedName(name = transfer.recipientName, lastUsed = System.currentTimeMillis()))
    }

    suspend fun deleteTransfer(transfer: Transfer) = transferDao.delete(transfer)
    fun getSavedNames(): Flow<List<SavedName>> = savedNameDao.getAll()
    suspend fun deleteAllData() {
        transferDao.deleteAll()
        accountDao.deleteAll()
        savedNameDao.deleteAll()
    }
}
