#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/Hawala_app"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${YELLOW}جاري تحميل الخطوط وإنشاء الأيقونات...${NC}"

# 1. تحميل خط Cairo
mkdir -p app/src/main/res/font
curl -sL -o app/src/main/res/font/cairo_regular.ttf "https://github.com/google/fonts/raw/main/ofl/cairo/static/Cairo-Regular.ttf"
curl -sL -o app/src/main/res/font/cairo_bold.ttf "https://github.com/google/fonts/raw/main/ofl/cairo/static/Cairo-Bold.ttf"

# 2. إنشاء أيقونة التطبيق (Vector)
mkdir -p app/src/main/res/drawable app/src/main/res/mipmap-anydpi-v26
cat > app/src/main/res/drawable/ic_launcher_background.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#000000"/>
</shape>
EOF

cat > app/src/main/res/drawable/ic_launcher_foreground.xml <<'EOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#00C853" android:pathData="M40,55 L55,40 L70,55 M55,40 L55,75" android:strokeColor="#00C853" android:strokeWidth="8" android:strokeLineCap="round" android:strokeLineJoin="round"/>
    <path android:fillColor="#E53935" android:pathData="M68,53 L53,68 L38,53 M53,68 L53,33" android:strokeColor="#E53935" android:strokeWidth="8" android:strokeLineCap="round" android:strokeLineJoin="round"/>
</vector>
EOF

cat > app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
EOF

# 3. تحديث AndroidManifest لاستخدام الأيقونة الجديدة
sed -i 's|@android:drawable/ic_menu_manage|@mipmap/ic_launcher|' app/src/main/AndroidManifest.xml

# 4. إضافة مكتبة البصمة في build.gradle.kts
sed -i '/implementation(libs.datastore.preferences)/a \    implementation("androidx.biometric:biometric:1.1.0")' app/build.gradle.kts

# 5. تحديث الخطوط في Theme
cat > app/src/main/java/com/transferslog/app/ui/theme/Theme.kt <<'EOF'
package com.transferslog.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.transferslog.app.R

val Black = Color(0xFF000000)
val DarkGray = Color(0xFF161616)
val LightGray = Color(0xFF1F1F1F)
val White = Color(0xFFFFFFFF)
val SecondaryText = Color(0xFF9E9E9E)
val GreenAccent = Color(0xFF00C853)
val RedAccent = Color(0xFFE53935)

private val DarkColorScheme = darkColorScheme(
    primary = GreenAccent, secondary = RedAccent, background = Black, surface = DarkGray,
    onPrimary = Black, onSecondary = White, onBackground = White, onSurface = White
)

val CairoFontFamily = FontFamily(
    Font(R.font.cairo_regular, FontWeight.Normal),
    Font(R.font.cairo_bold, FontWeight.Bold)
)

val AppTypography = Typography(
    bodyLarge = TextStyle(fontFamily = CairoFontFamily, fontSize = 16.sp),
    titleLarge = TextStyle(fontFamily = CairoFontFamily, fontWeight = FontWeight.Bold, fontSize = 22.sp),
    titleMedium = TextStyle(fontFamily = CairoFontFamily, fontWeight = FontWeight.Bold, fontSize = 18.sp)
)

@Composable
fun TransfersLogTheme(darkTheme: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = DarkColorScheme, typography = AppTypography, content = content)
}
EOF

# 6. إنشاء شاشة البداية وشاشة القفل
mkdir -p app/src/main/java/com/transferslog/app/ui/screens
cat > app/src/main/java/com/transferslog/app/ui/screens/SplashScreen.kt <<'EOF'
package com.transferslog.app.ui.screens

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.transferslog.app.R
import com.transferslog.app.ui.theme.Black
import com.transferslog.app.ui.theme.GreenAccent

@Composable
fun SplashScreen() {
    Box(modifier = Modifier.fillMaxSize().background(Black), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Image(painter = painterResource(id = R.drawable.ic_launcher_foreground), contentDescription = null, modifier = Modifier.size(120.dp))
            Spacer(Modifier.height(16.dp))
            Text("سجل الحوالات", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            Text("لإدارة أموالك باحترافية", color = GreenAccent, fontSize = 16.sp)
        }
    }
}
EOF

cat > app/src/main/java/com/transferslog/app/ui/screens/LockScreen.kt <<'EOF'
package com.transferslog.app.ui.screens

import androidx.activity.ComponentActivity
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.transferslog.app.ui.theme.Black
import com.transferslog.app.ui.theme.GreenAccent
import com.transferslog.app.ui.theme.White

@Composable
fun LockScreen(onUnlock: () -> Unit) {
    val context = LocalContext.current
    val activity = context as ComponentActivity

    val executor = ContextCompat.getMainExecutor(context)
    val biometricPrompt = BiometricPrompt(activity, executor, object : BiometricPrompt.AuthenticationCallback() {
        override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
            super.onAuthenticationSucceeded(result)
            onUnlock()
        }
    })

    val promptInfo = BiometricPrompt.PromptInfo.Builder()
        .setTitle("قفل التطبيق")
        .setSubtitle("الرجاء المصادقة للدخول")
        .setNegativeButtonText("إلغاء")
        .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.DEVICE_CREDENTIAL)
        .build()

    Box(modifier = Modifier.fillMaxSize().background(Black), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Default.Lock, contentDescription = null, tint = GreenAccent, modifier = Modifier.size(80.dp))
            Spacer(Modifier.height(24.dp))
            Text("التطبيق مقفل", color = White, fontSize = 24.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(32.dp))
            Button(
                onClick = { biometricPrompt.authenticate(promptInfo) },
                colors = ButtonDefaults.buttonColors(containerColor = GreenAccent)
            ) {
                Text("فتح القفل", color = Black, fontSize = 18.sp)
            }
        }
    }
}
EOF

# 7. تحديث MainActivity للربط
cat > app/src/main/java/com/transferslog/app/MainActivity.kt <<'EOF'
package com.transferslog.app

import android.os.Bundle
import androidx.activity.ComponentActivity
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

class MainActivity : ComponentActivity() {
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
EOF

echo -e "${GREEN}✓ تم إضافة الخطوط، الشاشة الافتتاحية، الأيقونة، وقفل البصمة.${NC}"

echo -e "${YELLOW}جاري رفع التحديثات إلى GitHub...${NC}"
git add .
git commit -m "Premium Update: Cairo Font, Custom Icon, Splash Screen, and Biometric App Lock"
git push -u origin main

echo -e "${GREEN}✅ التطبيق الآن أصبح فخماً ومحمياً! اذهب إلى GitHub Actions.${NC}"
