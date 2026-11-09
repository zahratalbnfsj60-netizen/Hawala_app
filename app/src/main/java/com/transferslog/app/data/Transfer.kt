package com.transferslog.app.data
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
object TransferType {
    const val PAID = "PAID"
    const val RECEIVED = "RECEIVED"
}
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
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val type: String,
    val recipientName: String,
    val amount: Double,
    val commission: Double = 0.0,
    val date: Long,
    val accountId: Long,
    val paidNumber: Int = 0,
    val createdAt: Long = System.currentTimeMillis()
)
