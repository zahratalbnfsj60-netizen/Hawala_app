package com.transferslog.app

import android.app.Application
import com.transferslog.app.data.AppSettings
import com.transferslog.app.data.Repository

class TransfersApplication : Application() {
    lateinit var repository: Repository
        private set
    lateinit var settings: AppSettings
        private set

    override fun onCreate() {
        super.onCreate()
        repository = Repository(this)
        settings = AppSettings(this)
    }
}
