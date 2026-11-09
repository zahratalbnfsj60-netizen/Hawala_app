package com.transferslog.app.data

import androidx.room.Entity
import androidx.room.PrimaryKey

enum class TransferType { PAID, RECEIVED }

@Entity(tableName = "accounts")
data class Account(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val openingBalance: Double = 0.0,
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "transfers")
data class Transfer(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val type: TransferType,
    val recipientName: String,
    val amount: Double,
    val commission: Double = 0.0,
    val date: Long,
    val accountId: Long,
    val paidNumber: Long? = null,
    val note: String? = null,
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "saved_names")
data class SavedName(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val lastUsed: Long = System.currentTimeMillis()
)
