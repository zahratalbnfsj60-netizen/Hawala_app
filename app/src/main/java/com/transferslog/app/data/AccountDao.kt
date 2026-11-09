package com.transferslog.app.data
import androidx.room.*
import kotlinx.coroutines.flow.Flow
@Dao
interface AccountDao {
    @Query("SELECT * FROM accounts ORDER BY createdAt ASC")
    fun getAllAccounts(): Flow<List<Account>>
    @Query("""
        SELECT a.id, a.name, a.openingBalance, a.createdAt,
            COALESCE((SELECT SUM(amount) FROM transfers WHERE accountId=a.id AND type='RECEIVED'), 0) AS received,
            COALESCE((SELECT SUM(amount) FROM transfers WHERE accountId=a.id AND type='PAID'), 0) AS paid,
            COALESCE((SELECT SUM(commission) FROM transfers WHERE accountId=a.id AND type='PAID'), 0) AS commission
        FROM accounts a ORDER BY a.createdAt ASC
    """)
    fun getAccountsWithBalance(): Flow<List<AccountWithBalance>>
    @Query("SELECT * FROM accounts WHERE id=:id")
    suspend fun getById(id: Long): Account?
    @Insert suspend fun insert(a: Account): Long
    @Update suspend fun update(a: Account)
    @Delete suspend fun delete(a: Account)
    @Query("DELETE FROM accounts") suspend fun deleteAll()
}
