package com.transferslog.app.data
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
@Entity(tableName = "saved_names", indices = [Index(value = ["name"], unique = true)])
data class SavedName(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val lastUsed: Long = System.currentTimeMillis()
)
