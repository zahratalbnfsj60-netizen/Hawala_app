package com.transferslog.app.data
class HawalaRepository(
    private val accountDao: AccountDao,
    private val transferDao: TransferDao,
    private val savedNameDao: SavedNameDao
) {
    fun accounts() = accountDao.getAllAccounts()
    fun accountsWithBalance() = accountDao.getAccountsWithBalance()
    suspend fun getAccount(id: Long) = accountDao.getById(id)
    suspend fun insertAccount(a: Account) = accountDao.insert(a)
    suspend fun updateAccount(a: Account) = accountDao.update(a)
    suspend fun deleteAccount(a: Account) = accountDao.delete(a)
    fun transfers(accId: Long) = transferDao.byAccount(accId)
    suspend fun getTransfer(id: Long) = transferDao.getById(id)
    suspend fun maxPaidNumber(accId: Long) = transferDao.maxPaidNumber(accId)
    suspend fun insertTransfer(t: Transfer) = transferDao.insert(t)
    suspend fun updateTransfer(t: Transfer) = transferDao.update(t)
    suspend fun deleteTransfer(t: Transfer) = transferDao.delete(t)
    suspend fun transfersInRange(accId: Long, from: Long, to: Long) = transferDao.inRange(accId, from, to)
    fun recentNames() = savedNameDao.recent()
    suspend fun rememberName(name: String) {
        if (name.isBlank()) return
        val existing = savedNameDao.find(name)
        if (existing != null) savedNameDao.update(existing.copy(lastUsed = System.currentTimeMillis()))
        else savedNameDao.insert(SavedName(name = name))
    }
    suspend fun wipeAll() {
        transferDao.deleteAll(); accountDao.deleteAll(); savedNameDao.deleteAll()
    }
}
