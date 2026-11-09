package com.transferslog.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.Composable
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.transferslog.app.ui.screens.*
import com.transferslog.app.ui.theme.TransfersTheme
import com.transferslog.app.viewmodel.MainViewModel
import com.transferslog.app.viewmodel.MainViewModelFactory

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val app = application as TransfersApplication
        val factory = MainViewModelFactory(app.repository, app.settings)
        setContent {
            TransfersTheme {
                AppNav(factory)
            }
        }
    }
}

@Composable
fun AppNav(factory: MainViewModelFactory) {
    val nav = rememberNavController()
    NavHost(nav, startDestination = "home") {
        composable("home") {
            val vm: MainViewModel = viewModel(factory = factory)
            HomeScreen(vm, nav)
        }
        composable("add/{type}/{id}") { entry ->
            val vm: MainViewModel = viewModel(factory = factory)
            AddEditTransferScreen(
                vm = vm,
                type = entry.arguments?.getString("type") ?: "PAID",
                editId = entry.arguments?.getString("id")?.toIntOrNull() ?: 0,
                onBack = { nav.popBackStack() }
            )
        }
        composable("accounts") {
            val vm: MainViewModel = viewModel(factory = factory)
            AccountsScreen(vm, nav)
        }
        composable("dashboard") {
            val vm: MainViewModel = viewModel(factory = factory)
            DashboardScreen(vm, nav)
        }
        composable("settings") {
            val vm: MainViewModel = viewModel(factory = factory)
            SettingsScreen(vm, nav)
        }
    }
}
