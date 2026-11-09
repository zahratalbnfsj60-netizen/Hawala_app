package com.transferslog.app.data

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.TypeConverter
import androidx.room.TypeConverters

class Converters {
    @TypeConverter
    fun fromTransferType(value: TransferType): String = value.name
    @TypeConverter
    fun toTransferType(value: String): TransferType = TransferType.valueOf(value)
}

@Database(
    entities = [Account::class, Transfer::class, SavedName::class],
    version = 1,
    exportSchema = false
)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun accountDao(): AccountDao
    abstract fun transferDao(): TransferDao
    abstract fun savedNameDao(): SavedNameDao
}
