package com.transferslog.app.util
import android.content.Context
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
object BiometricHelper {
    fun canAuthenticate(ctx: Context): Boolean {
        return BiometricManager.from(ctx).canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK or BiometricManager.Authenticators.DEVICE_CREDENTIAL) == BiometricManager.BIOMETRIC_SUCCESS
    }
    fun authenticate(activity: FragmentActivity, onSuccess: () -> Unit, onError: (String) -> Unit) {
        val executor = ContextCompat.getMainExecutor(activity)
        val prompt = BiometricPrompt(activity, executor, object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) = onSuccess()
            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) = onError(errString.toString())
        })
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle("سجل الحوالات")
            .setSubtitle("يرجى المصادقة للدخول")
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_WEAK or BiometricManager.Authenticators.DEVICE_CREDENTIAL)
            .build()
        prompt.authenticate(info)
    }
}
