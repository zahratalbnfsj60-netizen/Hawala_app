package com.transferslog.app.data
import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
@Database(entities = [Account::class, Transfer::class, SavedName::class], version = 1, exportSchema = false)
abstract class AppDatabase : RoomDatabase() {
    abstract fun accountDao(): AccountDao
    abstract fun transferDao(): TransferDao
    abstract fun savedNameDao(): SavedNameDao
    companion object {
        @Volatile private var INSTANCE: AppDatabase? = null
        fun get(ctx: Context): AppDatabase = INSTANCE ?: synchronized(this) {
            INSTANCE ?: Room.databaseBuilder(ctx.applicationContext, AppDatabase::class.java, "hawala.db")
                .fallbackToDestructiveMigration().build().also { INSTANCE = it }
        }
    }
}
