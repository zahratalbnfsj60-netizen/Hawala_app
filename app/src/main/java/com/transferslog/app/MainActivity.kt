package com.transferslog.app
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.fragment.app.FragmentActivity
import com.transferslog.app.ui.HawalaNavHost
import com.transferslog.app.ui.theme.HawalaTheme
class MainActivity : FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setBackgroundDrawableResource(android.R.color.black)
        setContent {
            HawalaTheme {
                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                    HawalaNavHost(activity = this)
                }
            }
        }
    }
}
