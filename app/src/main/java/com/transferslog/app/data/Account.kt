package com.transferslog.app.data
import androidx.room.Entity
import androidx.room.PrimaryKey
@Entity(tableName = "accounts")
data class Account(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val openingBalance: Double,
    val createdAt: Long = System.currentTimeMillis()
)
