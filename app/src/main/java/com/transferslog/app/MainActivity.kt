package com.transferslog.app

import android.os.Bundle
import androidx.fragment.app.FragmentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.transferslog.app.data.AppDatabase
import com.transferslog.app.data.Repository
import com.transferslog.app.ui.navigation.AppNavigation
import com.transferslog.app.ui.screens.LockScreen
import com.transferslog.app.ui.screens.SplashScreen
import com.transferslog.app.ui.theme.TransfersLogTheme
import kotlinx.coroutines.delay

class MainActivity : FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val database = AppDatabase.getDatabase(applicationContext)
        val repository = Repository(database)
        
        setContent {
            TransfersLogTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    var showSplash by remember { mutableStateOf(true) }
                    var isUnlocked by remember { mutableStateOf(false) }

                    LaunchedEffect(Unit) {
                        delay(1500)
                        showSplash = false
                    }

                    if (showSplash) {
                        SplashScreen()
                    } else if (!isUnlocked) {
                        LockScreen(onUnlock = { isUnlocked = true })
                    } else {
                        AppNavigation(repository)
                    }
                }
            }
        }
    }
}
