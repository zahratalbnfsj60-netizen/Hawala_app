package com.transferslog.app.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverter
import androidx.room.TypeConverters

class Converters {
    @TypeConverter fun fromTransferType(type: TransferType): String = type.name
    @TypeConverter fun toTransferType(value: String): TransferType = TransferType.valueOf(value)
}

@Database(entities = [Account::class, Transfer::class, SavedName::class], version = 1, exportSchema = false)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun accountDao(): AccountDao
    abstract fun transferDao(): TransferDao
    abstract fun savedNameDao(): SavedNameDao

    companion object {
        @Volatile private var INSTANCE: AppDatabase? = null
        fun getDatabase(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(context.applicationContext, AppDatabase::class.java, "transfers_log_database").build()
                INSTANCE = instance
                instance
            }
        }
    }
}
