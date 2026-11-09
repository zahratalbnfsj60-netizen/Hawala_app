package com.transferslog.app.data

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

enum class TransferType { PAID, RECEIVED }

@Entity(tableName = "accounts")
data class Account(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val name: String,
    val openingBalance: Double = 0.0,
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(
    tableName = "transfers",
    foreignKeys = [ForeignKey(
        entity = Account::class,
        parentColumns = ["id"],
        childColumns = ["accountId"],
        onDelete = ForeignKey.CASCADE
    )],
    indices = [Index("accountId")]
)
data class Transfer(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val type: TransferType,
    val recipientName: String,
    val amount: Double,
    val commission: Double = 0.0,
    val date: Long = System.currentTimeMillis(),
    val accountId: Int,
    val paidNumber: Int? = null,
    val note: String? = null,
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "saved_names", indices = [Index(value = ["name"], unique = true)])
data class SavedName(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val name: String,
    val lastUsed: Long = System.currentTimeMillis()
)
