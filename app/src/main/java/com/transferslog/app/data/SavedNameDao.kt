package com.transferslog.app.data
import androidx.room.*
import kotlinx.coroutines.flow.Flow
@Dao
interface SavedNameDao {
    @Query("SELECT * FROM saved_names ORDER BY lastUsed DESC LIMIT 30")
    fun recent(): Flow<List<SavedName>>
    @Query("SELECT * FROM saved_names WHERE name=:name LIMIT 1")
    suspend fun find(name: String): SavedName?
    @Insert(onConflict = OnConflictStrategy.IGNORE) suspend fun insert(s: SavedName): Long
    @Update suspend fun update(s: SavedName)
    @Query("DELETE FROM saved_names") suspend fun deleteAll()
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun insertAll(list: List<SavedName>)
}
