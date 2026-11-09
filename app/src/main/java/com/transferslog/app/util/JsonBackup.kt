package com.transferslog.app.util

import com.google.gson.Gson
import com.transferslog.app.data.*

data class BackupData(val accounts: List<Account>, val transfers: List<Transfer>, val savedNames: List<SavedName>)

object JsonBackup {
    private val gson = Gson()
    fun export(accounts: List<Account>, transfers: List<Transfer>, savedNames: List<SavedName>): String =
        gson.toJson(BackupData(accounts, transfers, savedNames))
    fun import(json: String): BackupData? = try { gson.fromJson(json, BackupData::class.java) } catch (e: Exception) { null }
}
