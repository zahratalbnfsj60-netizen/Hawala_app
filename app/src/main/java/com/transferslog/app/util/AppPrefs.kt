package com.transferslog.app.util
import android.content.Context
import androidx.compose.runtime.mutableStateOf
object AppPrefs {
    private const val N = "hawala_prefs"
    val currencyState = mutableStateOf("ل.س")
    val comm1State = mutableStateOf(100)
    val comm2State = mutableStateOf(250)
    fun init(ctx: Context) {
        val sp = ctx.getSharedPreferences(N, 0)
        currencyState.value = sp.getString("currency", "ل.س") ?: "ل.س"
        comm1State.value = sp.getInt("comm_1", 100)
        comm2State.value = sp.getInt("comm_2", 250)
    }
    fun setCurrency(ctx: Context, v: String) { ctx.getSharedPreferences(N, 0).edit().putString("currency", v).apply(); currencyState.value = v }
    fun setComm1(ctx: Context, v: Int) { ctx.getSharedPreferences(N, 0).edit().putInt("comm_1", v).apply(); comm1State.value = v }
    fun setComm2(ctx: Context, v: Int) { ctx.getSharedPreferences(N, 0).edit().putInt("comm_2", v).apply(); comm2State.value = v }
}
