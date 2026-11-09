package com.transferslog.app.data

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Dao
interface AccountDao {
    @Query("SELECT * FROM accounts ORDER BY name")
    fun getAll(): Flow<List<Account>>
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(account: Account): Long
    @Update
    suspend fun update(account: Account)
    @Delete
    suspend fun delete(account: Account)
    @Query("SELECT COUNT(*) FROM transfers WHERE accountId = :accountId")
    suspend fun transferCount(accountId: Int): Int
    @Query("SELECT * FROM accounts WHERE id = :id")
    suspend fun getById(id: Int): Account?
}

@Dao
interface TransferDao {
    @Query("SELECT * FROM transfers ORDER BY date DESC, createdAt DESC")
    fun getAll(): Flow<List<Transfer>>
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(transfer: Transfer): Long
    @Update
    suspend fun update(transfer: Transfer)
    @Delete
    suspend fun delete(transfer: Transfer)
    @Query("SELECT MAX(paidNumber) FROM transfers WHERE type = 'PAID'")
    suspend fun maxPaidNumber(): Int?
    @Query("DELETE FROM transfers")
    suspend fun deleteAll()
}

@Dao
interface SavedNameDao {
    @Query("SELECT * FROM saved_names ORDER BY lastUsed DESC")
    fun getAll(): Flow<List<SavedName>>
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(name: SavedName)
    @Query("DELETE FROM saved_names")
    suspend fun deleteAll()
}
