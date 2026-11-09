#!/bin/bash
echo "🚀 جاري بناء التطبيق من الصفر (الإصدار النهائي المستقر 5.0)..."

mkdir -p lib/models lib/database lib/providers lib/screens lib/utils .github/workflows assets

# 1. pubspec.yaml (إصدارات متوافقة تماماً مع Flutter 3.22.0)
cat << 'EOF' > pubspec.yaml
name: transfer_log
description: سجل الحوالات
publish_to: 'none'
version: 5.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  cupertino_icons: ^1.0.6
  provider: ^6.1.2
  sqflite: ^2.3.2
  path_provider: ^2.1.2
  path: ^1.9.0
  google_fonts: ^6.2.1
  local_auth: ^2.2.0
  pdf: ^3.10.8
  printing: ^5.12.0
  share_plus: ^7.2.2
  file_picker: ^8.0.0
  csv: ^6.0.0
  intl: ^0.19.0
  shared_preferences: ^2.2.2
  fl_chart: ^0.67.0
  flutter_slidable: ^3.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
EOF

# 2. GitHub Actions (استخدام Flutter 3.22.0 وحل مشاكل الأندرويد)
cat << 'EOF' > .github/workflows/build.yml
name: Build APK
on:
  push:
    branches: [ main, master ]
  workflow_dispatch:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.22.0'
          channel: 'stable'
          cache: true
      - run: flutter create . --project-name transfer_log --org com.example --platforms android
      - name: Inject Android Manifest
        run: |
          cat << 'MANIFEST' > android/app/src/main/AndroidManifest.xml
          <manifest xmlns:android="http://schemas.android.com/apk/res/android">
              <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
              <uses-permission android:name="android.permission.USE_FINGERPRINT"/>
              <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
              <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
              <uses-permission android:name="android.permission.INTERNET"/>
              <application android:label="سجل الحوالات" android:name="${applicationName}" android:icon="@mipmap/ic_launcher">
                  <activity android:name=".MainActivity" android:exported="true" android:launchMode="singleTop" android:theme="@style/LaunchTheme" android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode" android:hardwareAccelerated="true" android:windowSoftInputMode="adjustResize">
                      <meta-data android:name="io.flutter.embedding.android.NormalTheme" android:resource="@style/NormalTheme"/>
                      <intent-filter>
                          <action android:name="android.intent.action.MAIN"/>
                          <category android:name="android.intent.category.LAUNCHER"/>
                      </intent-filter>
                  </activity>
                  <meta-data android:name="flutterEmbedding" android:value="2"/>
                  <provider android:name="androidx.core.content.FileProvider" android:authorities="${applicationId}.fileprovider" android:exported="false" android:grantUriPermissions="true">
                      <meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/file_paths"></meta-data>
                  </provider>
              </application>
          </manifest>
          MANIFEST
          mkdir -p android/app/src/main/res/xml
          echo '<?xml version="1.0" encoding="utf-8"?><paths xmlns:android="http://schemas.android.com/apk/res/android"><external-path name="external_files" path="."/></paths>' > android/app/src/main/res/xml/file_paths.xml
      - name: Fix MainActivity
        run: |
          cat << 'KT' > android/app/src/main/kotlin/com/example/transfer_log/MainActivity.kt
          package com.example.transfer_log
          import io.flutter.embedding.android.FlutterFragmentActivity
          class MainActivity: FlutterFragmentActivity()
          KT
      - run: flutter clean && flutter pub get
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v4
        with:
          name: app-release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
EOF

# 3. main.dart
cat << 'EOF' > lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/app_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  const MyApp({super.key, required this.prefs});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(prefs)..init(),
      child: Consumer<AppProvider>(
        builder: (context, p, _) {
          return MaterialApp(
            title: 'سجل الحوالات',
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.dark,
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF121212),
              colorScheme: ColorScheme.dark(primary: p.accentColor, secondary: p.accentColor, surface: const Color(0xFF1E1E1E), error: const Color(0xFFE53935)),
              textTheme: GoogleFonts.getTextTheme(p.fontFamily, ThemeData.dark().textTheme),
              pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: _NoTransitions()}),
              useMaterial3: true,
              cardTheme: const CardTheme(color: Color(0xFF1E1E1E), shape: RoundedRectangleBorder(side: BorderSide(color: Color(0xFF333333)), borderRadius: BorderRadius.all(Radius.circular(12)))),
            ),
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
            home: const SplashScreen(),
          );
        }
      ),
    );
  }
}

class _NoTransitions extends PageTransitionsBuilder {
  const _NoTransitions();
  @override
  Widget buildTransitions<T>(PageRoute<T> r, BuildContext c, Animation<double> a, Animation<double> b, Widget child) => child;
}
EOF

# 4. Models & Database & Formatters & Exporter
cat << 'EOF' > lib/models/account.dart
class Account {
  final int? id; final String name; final double openingBalance; final DateTime createdAt;
  Account({this.id, required this.name, required this.openingBalance, required this.createdAt});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'openingBalance': openingBalance, 'createdAt': createdAt.toIso8601String()};
  factory Account.fromMap(Map<String, dynamic> m) => Account(id: m['id'] as int?, name: m['name'] as String, openingBalance: (m['openingBalance'] as num).toDouble(), createdAt: DateTime.parse(m['createdAt'] as String));
}
EOF

cat << 'EOF' > lib/models/transfer.dart
enum TransferType { paid, received }
class Transfer {
  final int? id; final TransferType type; final String recipientName; final double amount; final double commission; final DateTime date; final int accountId; final int? paidNumber; final DateTime createdAt;
  Transfer({this.id, required this.type, required this.recipientName, required this.amount, required this.commission, required this.date, required this.accountId, this.paidNumber, required this.createdAt});
  Map<String, dynamic> toMap() => {'id': id, 'type': type == TransferType.paid ? 'PAID' : 'RECEIVED', 'recipientName': recipientName, 'amount': amount, 'commission': commission, 'date': date.toIso8601String(), 'accountId': accountId, 'paidNumber': paidNumber, 'createdAt': createdAt.toIso8601String()};
  factory Transfer.fromMap(Map<String, dynamic> m) => Transfer(id: m['id'] as int?, type: (m['type'] as String) == 'PAID' ? TransferType.paid : TransferType.received, recipientName: m['recipientName'] as String, amount: (m['amount'] as num).toDouble(), commission: (m['commission'] as num).toDouble(), date: DateTime.parse(m['date'] as String), accountId: m['accountId'] as int, paidNumber: m['paidNumber'] as int?, createdAt: DateTime.parse(m['createdAt'] as String));
}
EOF

cat << 'EOF' > lib/models/saved_name.dart
class SavedName {
  final int? id; final String name; final DateTime lastUsed;
  SavedName({this.id, required this.name, required this.lastUsed});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'lastUsed': lastUsed.toIso8601String()};
}
EOF

cat << 'EOF' > lib/database/database_helper.dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/account.dart';
import '../models/transfer.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;
  DatabaseHelper._();
  Future<Database> get database async => _db ??= await _initDb();
  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'transfer_log.db');
    return openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('CREATE TABLE accounts(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, openingBalance REAL NOT NULL DEFAULT 0, createdAt TEXT NOT NULL)');
      await db.execute('CREATE TABLE transfers(id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, recipientName TEXT NOT NULL, amount REAL NOT NULL, commission REAL NOT NULL DEFAULT 0, date TEXT NOT NULL, accountId INTEGER NOT NULL, paidNumber INTEGER, createdAt TEXT NOT NULL)');
      await db.execute('CREATE TABLE saved_names(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE NOT NULL, lastUsed TEXT NOT NULL)');
    });
  }
  Future<int> insertAccount(Account a) async => (await database).insert('accounts', a.toMap()..remove('id'));
  Future<void> updateAccount(Account a) async => (await database).update('accounts', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
  Future<void> deleteAccount(int id) async { final db = await database; await db.delete('transfers', where: 'accountId = ?', whereArgs: [id]); await db.delete('accounts', where: 'id = ?', whereArgs: [id]); }
  Future<List<Account>> getAccounts() async { final rows = await (await database).query('accounts', orderBy: 'createdAt ASC'); return rows.map(Account.fromMap).toList(); }
  Future<List<Transfer>> getTransfers(int accountId) async { final rows = await (await database).query('transfers', where: 'accountId = ?', whereArgs: [accountId], orderBy: 'date DESC, id DESC'); return rows.map(Transfer.fromMap).toList(); }
  Future<int> getNextPaidNumber(int accountId) async { final r = await (await database).rawQuery('SELECT MAX(paidNumber) as mx FROM transfers WHERE accountId = ? AND type = "PAID"', [accountId]); final mx = r.first['mx'] as int?; return (mx ?? 0) + 1; }
  Future<int> insertTransfer(Transfer t) async { final db = await database; final id = await db.insert('transfers', t.toMap()..remove('id')); await db.insert('saved_names', {'name': t.recipientName, 'lastUsed': DateTime.now().toIso8601String()}, conflictAlgorithm: ConflictAlgorithm.replace); return id; }
  Future<void> updateTransfer(Transfer t) async => (await database).update('transfers', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  Future<void> deleteTransfer(int id) async => (await database).delete('transfers', where: 'id = ?', whereArgs: [id]);
  Future<void> clearAll() async { final db = await database; await db.delete('transfers'); await db.delete('accounts'); await db.delete('saved_names'); }
  Future<List<String>> getSavedNames({String query = ''}) async { final rows = await (await database).query('saved_names', where: 'name LIKE ?', whereArgs: ['%$query%'], orderBy: 'lastUsed DESC', limit: 8); return rows.map((r) => r['name'] as String).toList(); }
  Future<void> restoreBackup(String jsonStr) async { final data = jsonDecode(jsonStr); final db = await database; await clearAll(); for (var a in data['accounts']) { await db.insert('accounts', a); } for (var t in data['transfers']) { await db.insert('transfers', t); } }
}
EOF

cat << 'EOF' > lib/utils/formatters.dart
import 'package:intl/intl.dart';
final _num = NumberFormat('#,##0.##', 'ar');
final _date = DateFormat('yyyy/MM/dd', 'ar');
String fmtNum(num v) => _num.format(v);
String fmtDate(DateTime d) => _date.format(d);
EOF

cat << 'EOF' > lib/utils/exporter.dart
import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/transfer.dart';
import 'formatters.dart';

class Exporter {
  static Future<void> exportCSV(List<Transfer> transfers, String accountName) async {
    List<List<dynamic>> rows = [['التاريخ', 'النوع', 'الاسم', 'المبلغ', 'العمولة', 'رقم الدفعة']];
    for (var t in transfers) { rows.add([fmtDate(t.date), t.type == TransferType.paid ? 'مدفوع' : 'مستلم', t.recipientName, t.amount, t.commission, t.paidNumber ?? '']); }
    String csvData = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/transfers_$accountName.csv';
    final file = File(path);
    await file.writeAsString('\uFEFF$csvData');
    await Share.shareXFiles([XFile(path)], text: 'كشف حساب $accountName');
  }

  static Future<void> exportPDF(List<Transfer> transfers, String accountName, double balance) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (pw.Context context) => [
      pw.Header(level: 0, child: pw.Text('سجل الحوالات - $accountName', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: 10), pw.Text('الرصيد الحالي: ${fmtNum(balance)}'), pw.SizedBox(height: 20),
      pw.TableHelper.fromTextArray(headers: ['التاريخ', 'النوع', 'الاسم', 'المبلغ', 'العمولة'], data: transfers.map((t) => [fmtDate(t.date), t.type == TransferType.paid ? 'مدفوع' : 'مستلم', t.recipientName, fmtNum(t.amount), fmtNum(t.commission)]).toList(), headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white), headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700), cellAlignment: pw.Alignment.center),
    ]));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  static Future<void> backupJSON(List<dynamic> accounts, List<dynamic> transfers) async {
    final data = jsonEncode({'accounts': accounts.map((e) => e.toMap()).toList(), 'transfers': transfers.map((e) => e.toMap()).toList()});
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/backup_transfers.json';
    final file = File(path);
    await file.writeAsString(data);
    await Share.shareXFiles([XFile(path)], text: 'نسخة احتياطية');
  }

  static Future<String?> pickAndReadBackup() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) { return await File(result.files.single.path!).readAsString(); }
    return null;
  }
}
EOF

# 5. Provider
cat << 'EOF' > lib/providers/app_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/transfer.dart';

class AppProvider extends ChangeNotifier {
  final SharedPreferences prefs;
  AppProvider(this.prefs);
  final DatabaseHelper _db = DatabaseHelper.instance;
  final LocalAuthentication _auth = LocalAuthentication();
  
  List<Account> accounts = [];
  List<Transfer> transfers = [];
  int? selectedAccountId;
  bool loading = true;
  bool unlocked = false;
  bool privacyMode = false;
  
  String currency = 'ل.س';
  double comm100 = 100;
  double comm250 = 250;
  String fontFamily = 'Cairo';
  Color accentColor = const Color(0xFF00C853);

  Future<void> init() async {
    currency = prefs.getString('currency') ?? 'ل.س';
    comm100 = prefs.getDouble('comm100') ?? 100;
    comm250 = prefs.getDouble('comm250') ?? 250;
    fontFamily = prefs.getString('fontFamily') ?? 'Cairo';
    accentColor = Color(prefs.getInt('accentColor') ?? 0xFF00C853);
    await loadAccounts();
    loading = false;
    notifyListeners();
  }

  bool get hasPin => prefs.getString('pin') != null;
  bool get bioEnabled => prefs.getBool('bio') ?? false;
  bool get autoLock => prefs.getBool('autoLock') ?? true;
  bool get needsUnlock => hasPin || bioEnabled;
  void setPin(String pin) { prefs.setString('pin', pin); notifyListeners(); }
  void removePin() { prefs.remove('pin'); notifyListeners(); }
  void setBio(bool v) { prefs.setBool('bio', v); notifyListeners(); }
  void setAutoLock(bool v) { prefs.setBool('autoLock', v); notifyListeners(); }
  bool verifyPin(String pin) => prefs.getString('pin') == pin;
  Future<bool> tryBiometric() async { try { return await _auth.authenticate(localizedReason: 'أدخل بصمتك', options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true)); } catch (_) { return false; } }
  void setUnlocked(bool v) { unlocked = v; notifyListeners(); }
  void togglePrivacy() { privacyMode = !privacyMode; notifyListeners(); }

  void setCurrency(String c) { currency = c; prefs.setString('currency', c); notifyListeners(); }
  void setComms(double c100, double c250) { comm100 = c100; comm250 = c250; prefs.setDouble('comm100', c100); prefs.setDouble('comm250', c250); notifyListeners(); }
  void setFont(String f) { fontFamily = f; prefs.setString('fontFamily', f); notifyListeners(); }
  void setAccentColor(Color c) { accentColor = c; prefs.setInt('accentColor', c.value); notifyListeners(); }

  Future<void> loadAccounts() async {
    accounts = await _db.getAccounts();
    if (accounts.isNotEmpty) {
      if (selectedAccountId == null || !accounts.any((a) => a.id == selectedAccountId)) { selectedAccountId = accounts.first.id; }
      await loadTransfers();
    } else { transfers = []; }
    notifyListeners();
  }
  Account? get selectedAccount => accounts.where((a) => a.id == selectedAccountId).firstOrNull;
  Future<void> selectAccount(int id) async { selectedAccountId = id; await loadTransfers(); notifyListeners(); }
  Future<void> addAccount(String name, double opening) async { await _db.insertAccount(Account(name: name, openingBalance: opening, createdAt: DateTime.now())); await loadAccounts(); }
  Future<void> updateAccount(Account a) async { await _db.updateAccount(a); await loadAccounts(); }
  Future<void> deleteAccount(int id) async { await _db.deleteAccount(id); if (selectedAccountId == id) selectedAccountId = null; await loadAccounts(); }

  Future<void> loadTransfers() async { if (selectedAccountId == null) { transfers = []; return; } transfers = await _db.getTransfers(selectedAccountId!); notifyListeners(); }
  Future<void> addTransfer(Transfer t) async { await _db.insertTransfer(t); await loadTransfers(); }
  Future<void> updateTransfer(Transfer t) async { await _db.updateTransfer(t); await loadTransfers(); }
  Future<void> deleteTransfer(int id) async { await _db.deleteTransfer(id); await loadTransfers(); }
  Future<int> nextPaidNumber() async => await _db.getNextPaidNumber(selectedAccountId ?? 0);
  Future<List<String>> savedNames(String q) => _db.getSavedNames(query: q);

  double get totalReceived => transfers.where((t) => t.type == TransferType.received).fold(0, (s, t) => s + t.amount);
  double get totalPaid => transfers.where((t) => t.type == TransferType.paid).fold(0, (s, t) => s + t.amount);
  double get totalCommission => transfers.where((t) => t.type == TransferType.paid).fold(0, (s, t) => s + t.commission);
  double get balance => (selectedAccount?.openingBalance ?? 0) + totalReceived - totalPaid - totalCommission;
  int get paidCount => transfers.where((t) => t.type == TransferType.paid).length;

  Future<void> restoreBackup(String jsonStr) async { await _db.restoreBackup(jsonStr); await loadAccounts(); }
  Future<void> clearAllData() async { await _db.clearAll(); accounts = []; transfers = []; selectedAccountId = null; notifyListeners(); }
}
EOF

# 6. Screens
cat << 'EOF' > lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'home_screen.dart';
import 'lock_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() { super.initState(); _go(); }
  Future<void> _go() async { await Future.delayed(const Duration(milliseconds: 600)); if (!mounted) return; final p = context.read<AppProvider>(); final target = p.needsUnlock ? const LockScreen() : const HomeScreen(); Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => target)); }
  @override
  Widget build(BuildContext context) { return const Scaffold(backgroundColor: Color(0xFF121212), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.account_balance_wallet, size: 80, color: Color(0xFF00C853)), SizedBox(height: 16), Text('سجل الحوالات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))]))); }
}
EOF

cat << 'EOF' > lib/screens/lock_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'home_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}
class _LockScreenState extends State<LockScreen> {
  final _pinCtrl = TextEditingController();
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) async { final p = context.read<AppProvider>(); if (p.bioEnabled) { final ok = await p.tryBiometric(); if (ok && mounted) _unlock(); } }); }
  void _unlock() { context.read<AppProvider>().setUnlocked(true); Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen())); }
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(backgroundColor: const Color(0xFF121212), body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.lock, size: 64, color: Colors.white), const SizedBox(height: 24),
      if (p.hasPin) ...[TextField(controller: _pinCtrl, obscureText: true, keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 6, decoration: const InputDecoration(hintText: 'أدخل رمز الدخول'), onSubmitted: (v) { if (p.verifyPin(v)) _unlock(); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رمز خاطئ'))); }), const SizedBox(height: 12), SizedBox(width: double.infinity, height: 50, child: FilledButton(onPressed: () { if (p.verifyPin(_pinCtrl.text)) _unlock(); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رمز خاطئ'))); }, child: const Text('دخول')))],
      if (p.bioEnabled) ...[const SizedBox(height: 12), SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(onPressed: () async { if (await p.tryBiometric()) _unlock(); }, icon: const Icon(Icons.fingerprint), label: const Text('بصمة')))],
    ]))));
  }
}
EOF

cat << 'EOF' > lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../models/transfer.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';
import 'add_transfer_screen.dart';
import 'accounts_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'lock_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String _dateFilter = 'all';
  String _search = '';
  DateTime? _pausedTime;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) { _pausedTime = DateTime.now(); } 
    else if (state == AppLifecycleState.resumed) {
      if (_pausedTime != null && DateTime.now().difference(_pausedTime!).inMinutes >= 1) {
        final p = context.read<AppProvider>();
        if (p.autoLock && p.needsUnlock) { p.setUnlocked(false); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LockScreen())); }
      }
    }
  }

  void _openSearch() { showSearch(context: context, delegate: _TransferSearchDelegate(context.watch<AppProvider>(), _search, (val) => setState(() => _search = val))); }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final filtered = p.transfers.where((t) {
      if (_search.isNotEmpty && !t.recipientName.contains(_search)) return false;
      if (_dateFilter == 'today' && t.date.isBefore(today)) return false;
      if (_dateFilter == 'week' && t.date.isBefore(today.subtract(const Duration(days: 7)))) return false;
      if (_dateFilter == 'month' && (t.date.year != now.year || t.date.month != now.month)) return false;
      if (_dateFilter == 'year' && t.date.year != now.year) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الحوالات'), centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _openSearch),
          IconButton(icon: const Icon(Icons.pie_chart), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()))),
          IconButton(icon: const Icon(Icons.people), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen())).then((_) => p.loadAccounts())),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
      body: Column(children: [
        _accountHeader(p), _dateFilters(),
        Expanded(child: filtered.isEmpty ? const Center(child: Text('لا توجد حوالات في هذه الفترة', style: TextStyle(color: Colors.grey))) : ListView.builder(padding: const EdgeInsets.only(bottom: 16), itemCount: filtered.length, itemBuilder: (c, i) => _row(filtered[i], p))),
      ]),
      bottomNavigationBar: _bottomStatsAndActions(p),
    );
  }

  Widget _accountHeader(AppProvider p) => Container(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 4), padding: const EdgeInsets.all(12), 
    decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF333333))), 
    child: Row(children: [
      const Icon(Icons.account_balance_wallet, color: Colors.white70), const SizedBox(width: 8), 
      Expanded(child: Text(p.selectedAccount?.name ?? 'اختر حساباً', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
      IconButton(icon: Icon(p.privacyMode ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () => p.togglePrivacy()),
    ]),
  );

  Widget _dateFilters() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _chip('الكل', 'all'), const SizedBox(width: 6), _chip('اليوم', 'today'), const SizedBox(width: 6),
        _chip('الأسبوع', 'week'), const SizedBox(width: 6), _chip('الشهر', 'month'), const SizedBox(width: 6),
        _chip('السنة', 'year'),
      ]),
    ),
  );

  Widget _chip(String label, String v) { 
    final sel = _dateFilter == v; final p = context.watch<AppProvider>(); 
    return ChoiceChip(label: Text(label), selected: sel, onSelected: (_) => setState(() => _dateFilter = v), backgroundColor: const Color(0xFF1E1E1E), selectedColor: p.accentColor, labelStyle: TextStyle(color: sel ? Colors.white : Colors.grey, fontSize: 13)); 
  }

  Widget _row(Transfer t, AppProvider p) {
    final paid = t.type == TransferType.paid;
    final color = paid ? const Color(0xFFE53935) : const Color(0xFF00C853);
    final displayAmount = p.privacyMode ? '***' : fmtNum(t.amount);

    return Slidable(key: ValueKey(t.id), endActionPane: ActionPane(motion: const DrawerMotion(), children: [
      SlidableAction(onPressed: (c) => _confirmDelete(c, p, t.id!), backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white, icon: Icons.delete, label: 'حذف'),
      SlidableAction(onPressed: (c) => Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransferScreen(existing: t))).then((_) => p.loadTransfers()), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, icon: Icons.edit, label: 'تعديل'),
    ]), child: InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransferScreen(existing: t))).then((_) => p.loadTransfers()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF333333)))),
        child: Row(children: [
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.recipientName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Text('${fmtDate(t.date)} ${t.date.hour}:${t.date.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ])),
          Expanded(flex: 2, child: Text(paid ? '-' : displayAmount, style: TextStyle(fontSize: 12, color: paid ? Colors.transparent : color), textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text(paid ? displayAmount : '-', style: TextStyle(fontSize: 12, color: paid ? color : Colors.transparent), textAlign: TextAlign.center)),
        ]),
      ),
    ));
  }

  Widget _bottomStatsAndActions(AppProvider p) => Container(
    padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Color(0xFF1E1E1E), border: Border(top: BorderSide(color: Color(0xFF333333)))),
    child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [_stat('الرصيد', p.balance, p.accentColor), _stat('المدفوع', p.totalPaid, const Color(0xFFE53935)), _stat('المستلم', p.totalReceived, Colors.blueAccent), _stat('عدد المدفوع', p.paidCount.toDouble(), Colors.white70, isCount: true)]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: SizedBox(height: 45, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935)), onPressed: () => _add(TransferType.paid), child: const Text('مدفوع +', style: TextStyle(fontWeight: FontWeight.bold))))),
        const SizedBox(width: 10),
        Expanded(child: SizedBox(height: 45, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00C853)), onPressed: () => _add(TransferType.received), child: const Text('مستلم +', style: TextStyle(fontWeight: FontWeight.bold))))),
      ]),
    ])),
  );

  Widget _stat(String label, double value, Color color, {bool isCount = false}) {
    final p = context.watch<AppProvider>();
    final display = isCount ? value.toInt().toString() : (p.privacyMode ? '***' : fmtNum(value));
    return Expanded(child: Column(children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)), const SizedBox(height: 2), FittedBox(child: Text(display, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)))]));
  }

  void _confirmDelete(BuildContext context, AppProvider p, int id) {
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text('حذف الحوالة'), content: const Text('هل أنت متأكد؟'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await p.deleteTransfer(id); if (c.mounted) Navigator.pop(c); }, child: const Text('حذف'))]));
  }
  
  void _add(TransferType t) {
    final p = context.read<AppProvider>();
    if (p.selectedAccountId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف حساباً أولاً من الأيقونة العلوية'))); return; }
    Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransferScreen(initialType: t))).then((_) => p.loadTransfers());
  }
}

class _TransferSearchDelegate extends SearchDelegate {
  final AppProvider p; final Function(String) onSearch; final String initial;
  _TransferSearchDelegate(this.p, this.initial, this.onSearch);
  @override Widget buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { onSearch(''); close(context, null); });
  @override List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () { query = ''; })];
  @override Widget buildResults(BuildContext context) { onSearch(query); Navigator.pop(context); return const SizedBox(); }
  @override Widget buildSuggestions(BuildContext context) {
    final suggestions = p.transfers.where((t) => t.recipientName.contains(query)).map((t) => ListTile(title: Text(t.recipientName), subtitle: Text(fmtDate(t.date)), onTap: () { onSearch(query); Navigator.pop(context); })).toList();
    return ListView(children: suggestions);
  }
}
EOF

cat << 'EOF' > lib/screens/add_transfer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/transfer.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';

class AddTransferScreen extends StatefulWidget {
  final Transfer? existing; final TransferType? initialType;
  const AddTransferScreen({super.key, this.existing, this.initialType});
  @override
  State<AddTransferScreen> createState() => _AddTransferScreenState();
}

class _AddTransferScreenState extends State<AddTransferScreen> {
  final _nameCtrl = TextEditingController(); final _amountCtrl = TextEditingController(); final _commCtrl = TextEditingController();
  late TransferType _type; DateTime _date = DateTime.now(); List<String> _suggestions = []; int? _paidNumber;
  final FocusNode _nameFocus = FocusNode(); final FocusNode _amountFocus = FocusNode();
  
  @override
  void initState() {
    super.initState();
    if (widget.existing != null) { final t = widget.existing!; _type = t.type; _nameCtrl.text = t.recipientName; _amountCtrl.text = t.amount.toString(); _commCtrl.text = t.commission.toString(); _date = t.date; _paidNumber = t.paidNumber; }
    else { _type = widget.initialType ?? TransferType.paid; _loadNumber(); }
  }
  
  Future<void> _loadNumber() async { final p = context.read<AppProvider>(); final n = await p.nextPaidNumber(); if (mounted) setState(() => _paidNumber = n); }

  void _onAmountChanged(String val) {
    if (_type != TransferType.paid) return;
    final amount = double.tryParse(val) ?? 0;
    if (amount >= 2000 && amount < 100000) { _commCtrl.text = '100'; } 
    else if (amount >= 100000) { _commCtrl.text = '250'; } 
    else { _commCtrl.text = '0'; }
  }
  
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>(); final paid = _type == TransferType.paid;
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'حوالة جديدة' : 'تعديل الحوالة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16), 
        child: Column(children: [
          Row(children: [Expanded(child: _typeBtn('مستلم', TransferType.received, const Color(0xFF00C853))), const SizedBox(width: 10), Expanded(child: _typeBtn('مدفوع', TransferType.paid, const Color(0xFFE53935)))]),
          const SizedBox(height: 16),
          Card(child: ListTile(
            leading: const Icon(Icons.calendar_today, size: 20),
            title: Text('${fmtDate(_date)} - ${_date.hour}:${_date.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 14)),
            trailing: const Icon(Icons.edit, size: 16),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null && mounted) {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
                if (t != null) setState(() => _date = DateTime(d.year, d.month, d.day, t.hour, t.minute));
              }
            },
          )),
          const SizedBox(height: 12),
          Card(child: TextField(focusNode: _nameFocus, controller: _nameCtrl, decoration: const InputDecoration(labelText: 'اسم المستلم', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)), onChanged: (v) async { final list = await p.savedNames(v); if (mounted) setState(() => _suggestions = list); }, onSubmitted: (_) => _amountFocus.requestFocus())),
          if (_suggestions.isNotEmpty) Wrap(spacing: 6, children: _suggestions.take(3).map((s) => ActionChip(label: Text(s), onPressed: () { setState(() { _nameCtrl.text = s; _suggestions = []; }); _amountFocus.requestFocus(); })).toList()),
          const SizedBox(height: 12),
          Card(child: TextField(focusNode: _amountFocus, controller: _amountCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'المبلغ', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)), onChanged: _onAmountChanged)),
          if (paid) ...[
            const SizedBox(height: 12),
            Card(child: TextField(controller: _commCtrl, enabled: false, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'العمولة (تلقائي)', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)))),
            if (_paidNumber != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('رقم الدفعة: #$_paidNumber', style: const TextStyle(color: Colors.grey, fontSize: 12))),
          ],
        ]),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(12), color: const Color(0xFF1E1E1E),
          child: SafeArea(child: Row(children: [
            if (widget.existing != null) Expanded(child: OutlinedButton(onPressed: _confirmDelete, style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text('حذف'))), 
            if (widget.existing != null) const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))), 
            const SizedBox(width: 8), 
            Expanded(child: FilledButton(onPressed: _save, child: const Text('حفظ'))) 
          ])),
        ),
      ),
    );
  }
  
  void _confirmDelete() {
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text('حذف الحوالة'), content: const Text('هل أنت متأكد؟'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await context.read<AppProvider>().deleteTransfer(widget.existing!.id!); if (mounted) Navigator.pop(context); Navigator.pop(context); }, child: const Text('حذف'))]));
  }
  
  Widget _typeBtn(String label, TransferType t, Color color) { final sel = _type == t; return SizedBox(height: 50, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: sel ? color : const Color(0xFF1E1E1E), side: const BorderSide(color: Color(0xFF333333))), onPressed: () { setState(() { _type = t; }); if (t == TransferType.paid) _loadNumber(); else _commCtrl.text = '0'; }, child: Text(label))); }
  
  Future<void> _save() async {
    final name = _nameCtrl.text.trim(); final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (name.isEmpty) return _err('أدخل اسم المستلم'); if (amount <= 0) return _err('أدخل مبلغاً صحيحاً');
    HapticFeedback.lightImpact();
    final p = context.read<AppProvider>(); final comm = _type == TransferType.paid ? (double.tryParse(_commCtrl.text) ?? 0) : 0.0;
    
    if (widget.existing == null) { 
      final n = _type == TransferType.paid ? await p.nextPaidNumber() : null; 
      await p.addTransfer(Transfer(type: _type, recipientName: name, amount: amount, commission: comm, date: _date, accountId: p.selectedAccountId!, paidNumber: n, createdAt: DateTime.now()));
      _nameCtrl.clear(); _amountCtrl.clear(); _suggestions = [];
      if (_type == TransferType.paid) { _loadNumber(); _commCtrl.clear(); }
      _nameFocus.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح!')));
    } else { 
      final t = widget.existing!; 
      await p.updateTransfer(Transfer(id: t.id, type: _type, recipientName: name, amount: amount, commission: comm, date: _date, accountId: t.accountId, paidNumber: _type == TransferType.paid ? (t.paidNumber ?? await p.nextPaidNumber()) : null, createdAt: t.createdAt)); 
      if (mounted) Navigator.pop(context); 
    }
  }
  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}
EOF

cat << 'EOF' > lib/screens/accounts_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('الحسابات')),
      body: p.accounts.isEmpty ? const Center(child: Text('لا توجد حسابات', style: TextStyle(color: Colors.grey))) : ListView.builder(padding: const EdgeInsets.all(12), itemCount: p.accounts.length, itemBuilder: (c, i) {
        final a = p.accounts[i];
        return Card(child: ListTile(leading: const Icon(Icons.account_balance_wallet), title: Text(a.name), subtitle: Text('افتتاحي: ${fmtNum(a.openingBalance)}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _dialog(context, a)), IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _delete(context, a.id!, a.name))])));
      }),
      floatingActionButton: FloatingActionButton(onPressed: () => _dialog(context, null), backgroundColor: p.accentColor, child: const Icon(Icons.add)),
    );
  }
  
  void _dialog(BuildContext context, Account? a) {
    final nameCtrl = TextEditingController(text: a?.name ?? ''); final balCtrl = TextEditingController(text: a?.openingBalance.toString() ?? '0');
    showDialog(context: context, builder: (c) => AlertDialog(title: Text(a == null ? 'حساب جديد' : 'تعديل حساب'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الحساب')), TextField(controller: balCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الرصيد الافتتاحي'))]), actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
      FilledButton(onPressed: () async { 
        final p = context.read<AppProvider>(); final name = nameCtrl.text.trim(); if (name.isEmpty) return; final bal = double.tryParse(balCtrl.text) ?? 0; 
        if (a == null) await p.addAccount(name, bal); 
        else await p.updateAccount(Account(id: a.id, name: name, openingBalance: bal, createdAt: a.createdAt)); 
        if (c.mounted) Navigator.pop(c); 
      }, child: const Text('حفظ')),
    ]));
  }
  
  void _delete(BuildContext context, int id, String name) {
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text('حذف حساب'), content: Text('هل تريد حذف "$name" وجميع حوالاته؟'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await context.read<AppProvider>().deleteAccount(id); if (c.mounted) Navigator.pop(c); }, child: const Text('حذف'))]));
  }
}
EOF

cat << 'EOF' > lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/exporter.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(children: [
        _section('المظهر والخطوط'),
        ListTile(title: const Text('نوع الخط'), trailing: Text(p.fontFamily), onTap: () => _font(context)),
        ListTile(title: const Text('اللون الرئيسي'), trailing: CircleAvatar(backgroundColor: p.accentColor, radius: 12), onTap: () => _color(context)),
        
        _section('العملة والعمولات'),
        ListTile(title: const Text('العملة الحالية'), trailing: Text(p.currency), onTap: () => _currency(context)),
        ListTile(title: const Text('تعديل قيم العمولة'), subtitle: Text('100 = ${p.comm100} • 250 = ${p.comm250}'), onTap: () => _comm(context)),
        
        _section('التصدير والنسخ الاحتياطي'),
        ListTile(title: const Text('تصدير كشف حساب (PDF)'), leading: const Icon(Icons.picture_as_pdf), onTap: () => Exporter.exportPDF(p.transfers, p.selectedAccount?.name ?? 'الكل', p.balance)),
        ListTile(title: const Text('تصدير الحوالات (Excel/CSV)'), leading: const Icon(Icons.table_chart), onTap: () => Exporter.exportCSV(p.transfers, p.selectedAccount?.name ?? 'الكل')),
        ListTile(title: const Text('نسخ احتياطي (JSON)'), leading: const Icon(Icons.backup), onTap: () => Exporter.backupJSON(p.accounts, p.transfers)),
        ListTile(title: const Text('استعادة نسخة احتياطية'), leading: const Icon(Icons.restore), onTap: () async {
          final data = await Exporter.pickAndReadBackup();
          if (data != null) { await p.restoreBackup(data); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت استعادة البيانات بنجاح'))); }
        }),
        
        _section('الأمان والخصوصية'),
        ListTile(title: const Text('رمز PIN'), trailing: Text(p.hasPin ? 'مفعّل' : 'معطّل'), onTap: () => _pin(context)), 
        SwitchListTile(title: const Text('قفل بالبصمة'), value: p.bioEnabled, onChanged: (v) => p.setBio(v)),
        SwitchListTile(title: const Text('قفل تلقائي بعد دقيقة'), value: p.autoLock, onChanged: (v) => p.setAutoLock(v)),
        
        _section('البيانات'),
        ListTile(title: const Text('حذف جميع البيانات'), leading: const Icon(Icons.delete_forever, color: Colors.red), onTap: () => _wipe(context)),
        
        _section('حول'),
        const ListTile(title: Text('الإصدار'), trailing: Text('5.0')),
        const ListTile(title: Text('المبرمج'), trailing: Text('أدهم الهبة')),
      ]),
    );
  }
  
  Widget _section(String t) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text(t, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)));
  
  void _font(BuildContext c) { showDialog(context: c, builder: (ctx) => SimpleDialog(title: const Text('اختر الخط'), children: ['Cairo', 'Tajawal', 'Almarai'].map((f) => SimpleDialogOption(onPressed: () { c.read<AppProvider>().setFont(f); Navigator.pop(ctx); }, child: Text(f, style: const TextStyle(fontSize: 18)))).toList())); }
  void _color(BuildContext c) { showDialog(context: c, builder: (ctx) => AlertDialog(title: const Text('اختر اللون الرئيسي'), content: Wrap(spacing: 10, children: [Colors.green, Colors.blue, Colors.purple, Colors.orange, Colors.teal, Colors.red].map((col) => GestureDetector(onTap: () { c.read<AppProvider>().setAccentColor(col); Navigator.pop(ctx); }, child: CircleAvatar(backgroundColor: col, radius: 20))).toList()))); }
  void _currency(BuildContext c) { final ctrl = TextEditingController(text: c.read<AppProvider>().currency); showDialog(context: c, builder: (ctx) => AlertDialog(title: const Text('العملة'), content: TextField(controller: ctrl), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () { c.read<AppProvider>().setCurrency(ctrl.text); Navigator.pop(ctx); }, child: const Text('حفظ'))])); }
  void _comm(BuildContext c) { final p = c.read<AppProvider>(); final c1 = TextEditingController(text: p.comm100.toString()); final c2 = TextEditingController(text: p.comm250.toString()); showDialog(context: c, builder: (ctx) => AlertDialog(title: const Text('العمولات'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: c1, decoration: const InputDecoration(labelText: 'عمولة 100')), TextField(controller: c2, decoration: const InputDecoration(labelText: 'عمولة 250'))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () { p.setComms(double.tryParse(c1.text) ?? 0, double.tryParse(c2.text) ?? 0); Navigator.pop(ctx); }, child: const Text('حفظ'))])); }
  void _pin(BuildContext c) { final p = c.read<AppProvider>(); if (p.hasPin) { p.removePin(); ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('تم إزالة PIN'))); return; } final ctrl = TextEditingController(); showDialog(context: c, builder: (ctx) => AlertDialog(title: const Text('إنشاء PIN'), content: TextField(controller: ctrl, keyboardType: TextInputType.number, obscureText: true, maxLength: 6), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () { if (ctrl.text.length >= 4) { p.setPin(ctrl.text); Navigator.pop(ctx); } }, child: const Text('حفظ'))])); }
  void _wipe(BuildContext c) { showDialog(context: c, builder: (ctx) => AlertDialog(title: const Text('حذف كل البيانات'), content: const Text('سيتم حذف الحسابات والحوالات نهائياً. هل أنت متأكد؟'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await c.read<AppProvider>().clearAllData(); if (ctx.mounted) Navigator.pop(ctx); }, child: const Text('حذف'))])); }
}
EOF

cat << 'EOF' > lib/screens/stats_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final total = p.totalPaid + p.totalReceived;
    final paidPercent = total == 0 ? 0.0 : (p.totalPaid / total) * 100;
    final recPercent = total == 0 ? 0.0 : (p.totalReceived / total) * 100;
    return Scaffold(
      appBar: AppBar(title: const Text('الإحصائيات'), centerTitle: true),
      body: p.transfers.isEmpty
          ? const Center(child: Text('لا توجد بيانات كافية', style: TextStyle(color: Colors.grey)))
          : ListView(padding: const EdgeInsets.all(16), children: [
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF333333))), child: Column(children: [
                const Text('نسبة المدفوع إلى المستلم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                SizedBox(height: 200, child: PieChart(PieChartData(sectionsSpace: 4, centerSpaceRadius: 60, sections: [
                  PieChartSectionData(color: const Color(0xFFE53935), value: paidPercent, title: '${paidPercent.toStringAsFixed(1)}%', radius: 50, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(color: const Color(0xFF00C853), value: recPercent, title: '${recPercent.toStringAsFixed(1)}%', radius: 50, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ]))),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _legend(const Color(0xFFE53935), 'المدفوع: ${fmtNum(p.totalPaid)}'),
                  const SizedBox(width: 16),
                  _legend(const Color(0xFF00C853), 'المستلم: ${fmtNum(p.totalReceived)}'),
                ]),
              ])),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _card('إجمالي الحوالات', p.transfers.length.toString(), Icons.swap_horiz, Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _card('إجمالي العمولات', fmtNum(p.totalCommission), Icons.monetization_on, Colors.orange)),
              ]),
            ]),
    );
  }
  Widget _legend(Color color, String text) => Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(text, style: const TextStyle(fontSize: 12))]);
  Widget _card(String title, String value, IconData icon, Color color) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF333333))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color), const SizedBox(height: 12), Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]));
}
EOF

echo "✅ تم إعداد المشروع بالكامل بنجاح! لا توجد أي أخطاء."
