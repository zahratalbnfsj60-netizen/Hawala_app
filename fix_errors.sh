#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/Hawala_app"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${YELLOW}جاري إصلاح أخطاء الترجمة (Compilation Errors)...${NC}"

# 1. إصلاح SettingsViewModel (إضافة استيراد first)
sed -i 's/import kotlinx.coroutines.flow.map/import kotlinx.coroutines.flow.first\nimport kotlinx.coroutines.flow.map/' app/src/main/java/com/transferslog/app/ui/viewmodel/SettingsViewModel.kt

# 2. إصلاح AddEditTransferScreen (إضافة initial = emptyList())
sed -i 's/val accounts by vm.accounts.collectAsState()/val accounts by vm.accounts.collectAsState(initial = emptyList())/' app/src/main/java/com/transferslog/app/ui/screens/AddEditTransferScreen.kt
sed -i 's/val savedNames by vm.savedNames.collectAsState()/val savedNames by vm.savedNames.collectAsState(initial = emptyList())/' app/src/main/java/com/transferslog/app/ui/screens/AddEditTransferScreen.kt

# 3. إصلاح HomeScreen (الأيقونات والقيمة الافتراضية للتاريخ)
sed -i 's/import androidx.compose.material.icons.filled.\*/import androidx.compose.material.icons.filled.*/' app/src/main/java/com/transferslog/app/ui/screens/HomeScreen.kt
sed -i 's/Icons.Default.AccountBalance/Icons.Default.Person/' app/src/main/java/com/transferslog/app/ui/screens/HomeScreen.kt
sed -i 's/Icons.Default.BarChart/Icons.Default.List/' app/src/main/java/com/transferslog/app/ui/screens/HomeScreen.kt
sed -i 's/val dateRange by vm.dateRange.collectAsState()/val dateRange by vm.dateRange.collectAsState(initial = null)/' app/src/main/java/com/transferslog/app/ui/screens/HomeScreen.kt

# 4. إصلاح AccountsScreen و StatisticsScreen
sed -i 's/val accounts by vm.accountsWithBalance.collectAsState()/val accounts by vm.accountsWithBalance.collectAsState(initial = emptyList())/' app/src/main/java/com/transferslog/app/ui/screens/AccountsScreen.kt
sed -i 's/val stats by vm.stats.collectAsState()/val stats by vm.stats.collectAsState(initial = StatisticsData())/' app/src/main/java/com/transferslog/app/ui/screens/StatisticsScreen.kt

echo -e "${GREEN}✓ تم إصلاح جميع الأخطاء برمجياً.${NC}"

# رفع التعديلات
echo -e "${YELLOW}جاري رفع الإصلاحات إلى GitHub...${NC}"
git add .
git commit -m "Fix compilation errors: collectAsState initial values, icons, and flow first()"
git push -u origin main

echo -e "${GREEN}✅ تم الإصلاح والرفع بنجاح! اذهب لصفحة Actions في GitHub لترى البناء يعمل الآن.${NC}"
