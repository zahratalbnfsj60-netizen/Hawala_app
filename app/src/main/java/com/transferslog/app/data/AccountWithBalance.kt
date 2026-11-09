package com.transferslog.app.data
data class AccountWithBalance(
    val id: Long,
    val name: String,
    val openingBalance: Double,
    val createdAt: Long,
    val received: Double,
    val paid: Double,
    val commission: Double
) {
    val balance: Double get() = openingBalance + received - paid - commission
}
