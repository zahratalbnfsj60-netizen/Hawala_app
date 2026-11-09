package com.transferslog.app.data

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Dao
interface AccountDao {
    @Query("SELECT * FROM accounts ORDER BY createdAt DESC")
    fun getAll(): Flow<List<Account>>
    @Query("SELECT * FROM accounts WHERE id = :id")
    suspend fun getById(id: Long): Account?
    @Insert
    suspend fun insert(account: Account): Long
    @Update
    suspend fun update(account: Account)
    @Delete
    suspend fun delete(account: Account)
    @Query("DELETE FROM accounts")
    suspend fun deleteAll()
}

@Dao
interface TransferDao {
    @Query("""
        SELECT * FROM transfers 
        WHERE accountId = :accountId
        AND (:type IS NULL OR type = :type)
        AND (:searchQuery = '' OR recipientName LIKE '%' || :searchQuery || '%' OR CAST(amount AS TEXT) LIKE '%' || :searchQuery || '%')
        AND (:startDate IS NULL OR date >= :startDate)
        AND (:endDate IS NULL OR date <= :endDate)
        ORDER BY date DESC, createdAt DESC
    """)
    fun getFiltered(accountId: Long, type: TransferType?, searchQuery: String, startDate: Long?, endDate: Long?): Flow<List<Transfer>>
    @Query("SELECT * FROM transfers WHERE id = :id")
    suspend fun getById(id: Long): Transfer?
    @Insert
    suspend fun insert(transfer: Transfer): Long
    @Update
    suspend fun update(transfer: Transfer)
    @Delete
    suspend fun delete(transfer: Transfer)
    @Query("SELECT MAX(paidNumber) FROM transfers WHERE type = 'PAID' AND accountId = :accountId")
    suspend fun getMaxPaidNumber(accountId: Long): Long?
    @Query("DELETE FROM transfers WHERE accountId = :accountId")
    suspend fun deleteByAccountId(accountId: Long)
    @Query("DELETE FROM transfers")
    suspend fun deleteAll()
}

@Dao
interface SavedNameDao {
    @Query("SELECT * FROM saved_names ORDER BY lastUsed DESC")
    fun getAll(): Flow<List<SavedName>>
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(savedName: SavedName)
    @Query("DELETE FROM saved_names")
    suspend fun deleteAll()
}
