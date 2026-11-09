package com.transferslog.app.ui.navigation

import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.*
import androidx.navigation.navArgument
import com.transferslog.app.data.Repository
import com.transferslog.app.data.TransferType
import com.transferslog.app.ui.screens.*
import com.transferslog.app.ui.viewmodel.*

@Composable
fun AppNavigation(repo: Repository) {
    val nav = rememberNavController()
    NavHost(navController = nav, startDestination = "home", enterTransition = { EnterTransition.None }, exitTransition = { ExitTransition.None }) {
        composable("home") {
            val vm: MainViewModel = viewModel { MainViewModel(repo) }
            HomeScreen(vm, onAdd = { nav.navigate("add_edit?type=${it.name}") }, onEdit = { nav.navigate("add_edit?id=$it") }, onNavAcc = { nav.navigate("accounts") }, onNavSettings = { nav.navigate("settings") })
        }
        composable("add_edit?id={id}&type={type}", arguments = listOf(navArgument("id") { type = NavType.LongType; defaultValue = -1L }, navArgument("type") { type = NavType.StringType; defaultValue = TransferType.RECEIVED.name })) { backStack ->
            val id = backStack.arguments?.getLong("id")?.takeIf { it > 0 }
            val mainVm: MainViewModel = viewModel { MainViewModel(repo) }
            val accountId = mainVm.selectedAccountId.collectAsState().value
            if (accountId != null) {
                val vm: AddEditViewModel = viewModel { AddEditViewModel(repo, accountId!!) }
                AddEditTransferScreen(vm, id) { nav.popBackStack() }
            }
        }
        composable("accounts") {
            val vm: AccountsViewModel = viewModel { AccountsViewModel(repo) }
            AccountsScreen(vm) { nav.popBackStack() }
        }
        composable("settings") {
            val ctx = LocalContext.current
            val vm: SettingsViewModel = viewModel { SettingsViewModel(repo, ctx) }
            SettingsScreen(vm) { nav.popBackStack() }
        }
    }
}
