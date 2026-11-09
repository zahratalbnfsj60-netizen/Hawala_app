package com.transferslog.app.data

import android.content.Context

class AppSettings(context: Context) {
    private val prefs = context.getSharedPreferences("app_settings", Context.MODE_PRIVATE)

    var currency: String
        get() = prefs.getString("currency", "ل.س") ?: "ل.س"
        set(v) = prefs.edit().putString("currency", v).apply()

    var commission1: Double
        get() = prefs.getFloat("commission1", 100f).toDouble()
        set(v) = prefs.edit().putFloat("commission1", v.toFloat()).apply()

    var commission2: Double
        get() = prefs.getFloat("commission2", 250f).toDouble()
        set(v) = prefs.edit().putFloat("commission2", v.toFloat()).apply()

    var defaultCommissionIsFirst: Boolean
        get() = prefs.getBoolean("defaultCommissionIsFirst", true)
        set(v) = prefs.edit().putBoolean("defaultCommissionIsFirst", v).apply()
}
