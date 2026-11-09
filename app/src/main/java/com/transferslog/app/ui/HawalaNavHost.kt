package com.transferslog.app.ui

import androidx.compose.animation.*
import androidx.compose.runtime.Composable
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.*
import androidx.navigation.navArgument
import com.transferslog.app.ui.screens.*

@Composable
fun HawalaNavHost(activity: FragmentActivity) {
    val nav = rememberNavController()
    val vm: MainViewModel = viewModel()
    NavHost(
        navController = nav,
        startDestination = "splash",
        enterTransition = { EnterTransition.None },
        exitTransition = { ExitTransition.None },
        popEnterTransition = { EnterTransition.None },
        popExitTransition = { ExitTransition.None }
    ) {
        composable("splash") {
            SplashScreen {
                if (com.transferslog.app.util.BiometricHelper.canAuthenticate(activity))
                    nav.navigate("lock") { popUpTo("splash") { inclusive = true } }
                else nav.navigate("home") { popUpTo("splash") { inclusive = true } }
            }
        }
        composable("lock") {
            LockScreen(activity) {
                nav.navigate("home") { popUpTo("lock") { inclusive = true } }
            }
        }
        composable("home") {
            HomeScreen(
                vm = vm,
                onOpenAccounts = { nav.navigate("accounts") },
                onOpenSettings = { nav.navigate("settings") },
                onAddTransfer = { type -> nav.navigate("addEdit?type=\$type") },
                onEditTransfer = { id -> nav.navigate("addEdit?id=\$id") }
            )
        }
        composable(
            "addEdit?type={type}&id={id}",
            arguments = listOf(
                navArgument("type") { type = NavType.StringType; defaultValue = "PAID" },
                navArgument("id") { type = NavType.LongType; defaultValue = -1L }
            )
        ) { back ->
            val type = back.arguments?.getString("type") ?: "PAID"
            val id = back.arguments?.getLong("id") ?: -1L
            AddEditScreen(vm = vm, initialType = type, transferId = if (id > 0) id else null,
                onClose = { nav.popBackStack() })
        }
        composable("accounts") {
            AccountsScreen(vm = vm, onBack = { nav.popBackStack() })
        }
        composable("settings") {
            SettingsScreen(vm = vm, onBack = { nav.popBackStack() })
        }
    }
}
