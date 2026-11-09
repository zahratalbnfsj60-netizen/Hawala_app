package com.transferslog.app.data
import androidx.room.*
import kotlinx.coroutines.flow.Flow
@Dao
interface TransferDao {
    @Query("SELECT * FROM transfers WHERE accountId=:accId ORDER BY date DESC, id DESC")
    fun byAccount(accId: Long): Flow<List<Transfer>>
    @Query("SELECT * FROM transfers WHERE id=:id")
    suspend fun getById(id: Long): Transfer?
    @Query("SELECT COALESCE(MAX(paidNumber), 0) FROM transfers WHERE accountId=:accId AND type='PAID'")
    suspend fun maxPaidNumber(accId: Long): Int
    @Query("SELECT * FROM transfers WHERE accountId=:accId AND date BETWEEN :from AND :to ORDER BY date ASC, id ASC")
    suspend fun inRange(accId: Long, from: Long, to: Long): List<Transfer>
    @Query("SELECT * FROM transfers ORDER BY id ASC")
    suspend fun allForBackup(): List<Transfer>
    @Insert suspend fun insert(t: Transfer): Long
    @Update suspend fun update(t: Transfer)
    @Delete suspend fun delete(t: Transfer)
    @Query("DELETE FROM transfers") suspend fun deleteAll()
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun insertAll(list: List<Transfer>)
}
