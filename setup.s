#!/bin/bash
echo "🚀 بدء إنشاء هيكل تطبيق سجل الحوالات..."

# إنشاء المجلدات
mkdir -p lib/models lib/database lib/providers lib/screens lib/utils .github/workflows assets

# 1. pubspec.yaml
cat << 'EOF' > pubspec.yaml
name: transfer_log
description: سجل الحوالات - إدارة الحوالات المالية
publish_to: 'none'
version: 2.0.0+1

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

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  flutter_launcher_icons: ^0.13.1
  flutter_native_splash: ^2.4.0

flutter:
  uses-material-design: true
EOF

# 2. flutter_launcher_icons.yaml
cat << 'EOF' > flutter_launcher_icons.yaml
flutter_launcher_icons:
  android: "launcher_icon"
  ios: false
  image_path: "assets/icon.png"
  min_sdk_android: 24
  adaptive_icon_background: "#000000"
  adaptive_icon_foreground: "assets/icon.png"
EOF

# 3. flutter_native_splash.yaml
cat << 'EOF' > flutter_native_splash.yaml
flutter_native_splash:
  color: "#000000"
  image: "assets/splash.png"
  color_dark: "#000000"
  image_dark: "assets/splash.png"
  android_12:
    color: "#000000"
    image: "assets/splash.png"
EOF

# 4. Models
cat << 'EOF' > lib/models/account.dart
class Account {
  final int? id;
  final String name;
  final double openingBalance;
  final DateTime createdAt;
  Account({this.id, required this.name, required this.openingBalance, required this.createdAt});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'openingBalance': openingBalance, 'createdAt': createdAt.toIso8601String()};
  factory Account.fromMap(Map<String, dynamic> m) => Account(id: m['id'] as int?, name: m['name'] as String, openingBalance: (m['openingBalance'] as num).toDouble(), createdAt: DateTime.parse(m['createdAt'] as String));
}
EOF

cat << 'EOF' > lib/models/transfer.dart
enum TransferType { paid, received }
class Transfer {
  final int? id;
  final TransferType type;
  final String recipientName;
  final double amount;
  final double commission;
  final DateTime date;
  final int accountId;
  final int? paidNumber;
  final DateTime createdAt;
  Transfer({this.id, required this.type, required this.recipientName, required this.amount, required this.commission, required this.date, required this.accountId, this.paidNumber, required this.createdAt});
  Map<String, dynamic> toMap() => {'id': id, 'type': type == TransferType.paid ? 'PAID' : 'RECEIVED', 'recipientName': recipientName, 'amount': amount, 'commission': commission, 'date': date.toIso8601String(), 'accountId': accountId, 'paidNumber': paidNumber, 'createdAt': createdAt.toIso8601String()};
  factory Transfer.fromMap(Map<String, dynamic> m) => Transfer(id: m['id'] as int?, type: (m['type'] as String) == 'PAID' ? TransferType.paid : TransferType.received, recipientName: m['recipientName'] as String, amount: (m['amount'] as num).toDouble(), commission: (m['commission'] as num).toDouble(), date: DateTime.parse(m['date'] as String), accountId: m['accountId'] as int, paidNumber: m['paidNumber'] as int?, createdAt: DateTime.parse(m['createdAt'] as String));
}
EOF

cat << 'EOF' > lib/models/saved_name.dart
class SavedName {
  final int? id;
  final String name;
  final DateTime lastUsed;
  SavedName({this.id, required this.name, required this.lastUsed});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'lastUsed': lastUsed.toIso8601String()};
  factory SavedName.fromMap(Map<String, dynamic> m) => SavedName(id: m['id'] as int?, name: m['name'] as String, lastUsed: DateTime.parse(m['lastUsed'] as String));
}
EOF

# 5. Database Helper
cat << 'EOF' > lib/database/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/account.dart';
import '../models/transfer.dart';
import '../models/saved_name.dart';

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
}
EOF

# 6. Provider
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
  String currency = 'ل.س';
  double comm100 = 100;
  double comm250 = 250;

  Future<void> init() async {
    currency = prefs.getString('currency') ?? 'ل.س';
    comm100 = prefs.getDouble('comm100') ?? 100;
    comm250 = prefs.getDouble('comm250') ?? 250;
    await loadAccounts();
    loading = false;
    notifyListeners();
  }

  bool get hasPin => prefs.getString('pin') != null;
  bool get bioEnabled => prefs.getBool('bio') ?? false;
  bool get needsUnlock => hasPin || bioEnabled;
  void setPin(String pin) { prefs.setString('pin', pin); notifyListeners(); }
  void removePin() { prefs.remove('pin'); notifyListeners(); }
  void setBio(bool v) { prefs.setBool('bio', v); notifyListeners(); }
  bool verifyPin(String pin) => prefs.getString('pin') == pin;
  Future<bool> tryBiometric() async { try { return await _auth.authenticate(localizedReason: 'أدخل بصمتك للدخول', options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true)); } catch (_) { return false; } }
  void setUnlocked(bool v) { unlocked = v; notifyListeners(); }

  void setCurrency(String c) { currency = c; prefs.setString('currency', c); notifyListeners(); }
  void setComms(double c100, double c250) { comm100 = c100; comm250 = c250; prefs.setDouble('comm100', c100); prefs.setDouble('comm250', c250); notifyListeners(); }

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
  int get count => transfers.length;
  Future<void> clearAllData() async { await _db.clearAll(); accounts = []; transfers = []; selectedAccountId = null; notifyListeners(); }
}
EOF

# 7. Utils
cat << 'EOF' > lib/utils/formatters.dart
import 'package:intl/intl.dart';
final _num = NumberFormat('#,##0.##', 'ar');
final _date = DateFormat('yyyy/MM/dd', 'ar');
String fmtNum(num v) => _num.format(v);
String fmtDate(DateTime d) => _date.format(d);
EOF

# 8. Main
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
      child: MaterialApp(
        title: 'سجل الحوالات',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.black,
          colorScheme: const ColorScheme.dark(primary: Colors.white, secondary: Color(0xFF00C853), surface: Color(0xFF161616), error: Color(0xFFE53935)),
          textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
          pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: _NoTransitions()}),
          useMaterial3: true,
        ),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const SplashScreen(),
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

# 9. Splash Screen
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
  Future<void> _go() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final p = context.read<AppProvider>();
    final target = p.needsUnlock ? const LockScreen() : const HomeScreen();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => target));
  }
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.account_balance_wallet, size: 80, color: Color(0xFF00C853)),
        SizedBox(height: 16),
        Text('سجل الحوالات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      ])),
    );
  }
}
EOF

# 10. Lock Screen
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<AppProvider>();
      if (p.bioEnabled) {
        final ok = await p.tryBiometric();
        if (ok && mounted) _unlock();
      }
    });
  }
  void _unlock() {
    context.read<AppProvider>().setUnlocked(true);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock, size: 64, color: Colors.white),
            const SizedBox(height: 24),
            if (p.hasPin) ...[
              TextField(controller: _pinCtrl, obscureText: true, keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 6, decoration: const InputDecoration(hintText: 'أدخل رمز الدخول'), onSubmitted: (v) { if (p.verifyPin(v)) _unlock(); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رمز خاطئ'))); }),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 50, child: FilledButton(onPressed: () { if (p.verifyPin(_pinCtrl.text)) _unlock(); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رمز خاطئ'))); }, child: const Text('دخول'))),
            ],
            if (p.bioEnabled) ...[
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(onPressed: () async { if (await p.tryBiometric()) _unlock(); }, icon: const Icon(Icons.fingerprint), label: const Text('بصمة'))),
            ],
          ]),
        ),
      ),
    );
  }
}
EOF

# 11. Home Screen
cat << 'EOF' > lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transfer.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';
import 'add_transfer_screen.dart';
import 'accounts_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _filter = 'all';
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final filtered = p.transfers.where((t) {
      if (_filter == 'paid' && t.type != TransferType.paid) return false;
      if (_filter == 'received' && t.type != TransferType.received) return false;
      if (_search.isNotEmpty && !t.recipientName.contains(_search)) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('سجل الحوالات'), actions: [
        IconButton(icon: const Icon(Icons.people), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen())).then((_) => p.loadAccounts())),
        IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
      ]),
      body: Column(children: [
        _header(p),
        _filters(),
        _searchBar(),
        Expanded(child: filtered.isEmpty ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.receipt_long, size: 80, color: Colors.grey), SizedBox(height: 12), Text('لا توجد حوالات بعد', style: TextStyle(color: Colors.grey, fontSize: 16))])) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: filtered.length, itemBuilder: (c, i) => _card(filtered[i], p))),
      ]),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: _bigBtn('مدفوع +', const Color(0xFFE53935), () => _add(TransferType.paid))),
        const SizedBox(width: 10),
        Expanded(child: _bigBtn('مستلم +', const Color(0xFF00C853), () => _add(TransferType.received))),
      ]))),
    );
  }

  Widget _header(AppProvider p) => Container(margin: const EdgeInsets.fromLTRB(12, 8, 12, 4), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(14)), child: Column(children: [
    Row(children: [const Icon(Icons.account_balance_wallet, color: Colors.white70), const SizedBox(width: 8), Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<int>(value: p.selectedAccountId, isExpanded: true, dropdownColor: const Color(0xFF1F1F1F), hint: const Text('اختر حساباً'), items: p.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(), onChanged: (v) { if (v != null) p.selectAccount(v); })))]),
    const SizedBox(height: 12),
    Row(children: [_stat('الرصيد', p.balance, const Color(0xFF00C853)), _stat('المدفوع', p.totalPaid, const Color(0xFFE53935)), _stat('المستلم', p.totalReceived, Colors.blueAccent), _stat('العدد', p.count.toDouble(), Colors.white70, isCount: true)]),
  ]));

  Widget _stat(String label, double value, Color color, {bool isCount = false}) => Expanded(child: Column(children: [
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)), const SizedBox(height: 4),
    FittedBox(child: Text(isCount ? value.toInt().toString() : fmtNum(value), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14))),
  ]));

  Widget _filters() => Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Row(children: [
    _chip('الكل', 'all'), const SizedBox(width: 6),
    _chip('مستلم', 'received'), const SizedBox(width: 6),
    _chip('مدفوع', 'paid'),
  ]));

  Widget _chip(String label, String v) {
    final sel = _filter == v;
    return ChoiceChip(label: Text(label), selected: sel, onSelected: (_) => setState(() => _filter = v), backgroundColor: const Color(0xFF161616), selectedColor: Colors.white, labelStyle: TextStyle(color: sel ? Colors.black : Colors.white));
  }

  Widget _searchBar() => Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 6), child: TextField(onChanged: (v) => setState(() => _search = v), decoration: InputDecoration(hintText: 'بحث عن اسم...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: const Color(0xFF161616), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 0))));

  Widget _card(Transfer t, AppProvider p) {
    final paid = t.type == TransferType.paid;
    final color = paid ? const Color(0xFFE53935) : const Color(0xFF00C853);
    return Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(12), border: Border(right: BorderSide(color: color, width: 4))), child: ListTile(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransferScreen(existing: t))).then((_) => p.loadTransfers()),
      title: Text(t.recipientName, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${fmtDate(t.date)}${t.paidNumber != null ? " • #${t.paidNumber}" : ""}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${paid ? "-" : "+"}${fmtNum(t.amount)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        if (t.commission > 0) Text('عمولة: ${fmtNum(t.commission)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    ));
  }

  Widget _bigBtn(String label, Color color, VoidCallback onTap) => SizedBox(height: 55, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white), onPressed: onTap, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))));

  void _add(TransferType t) {
    final p = context.read<AppProvider>();
    if (p.selectedAccountId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف حساباً أولاً'))); return; }
    Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransferScreen(initialType: t))).then((_) => p.loadTransfers());
  }
}
EOF

# 12. Add Transfer Screen
cat << 'EOF' > lib/screens/add_transfer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/transfer.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';

class AddTransferScreen extends StatefulWidget {
  final Transfer? existing;
  final TransferType? initialType;
  const AddTransferScreen({super.key, this.existing, this.initialType});
  @override
  State<AddTransferScreen> createState() => _AddTransferScreenState();
}

class _AddTransferScreenState extends State<AddTransferScreen> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _commCtrl = TextEditingController();
  late TransferType _type;
  DateTime _date = DateTime.now();
  List<String> _suggestions = [];
  int? _paidNumber;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final t = widget.existing!;
      _type = t.type; _nameCtrl.text = t.recipientName; _amountCtrl.text = t.amount.toString(); _commCtrl.text = t.commission.toString(); _date = t.date; _paidNumber = t.paidNumber;
    } else {
      _type = widget.initialType ?? TransferType.paid;
      _loadNumber();
    }
    if (widget.existing == null && _type == TransferType.paid) { _commCtrl.text = context.read<AppProvider>().comm100.toString(); }
  }

  Future<void> _loadNumber() async { final p = context.read<AppProvider>(); final n = await p.nextPaidNumber(); if (mounted) setState(() => _paidNumber = n); }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final paid = _type == TransferType.paid;
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'حوالة جديدة' : 'تعديل الحوالة')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [Expanded(child: _typeBtn('مستلم', TransferType.received, const Color(0xFF00C853))), const SizedBox(width: 10), Expanded(child: _typeBtn('مدفوع', TransferType.paid, const Color(0xFFE53935)))]),
        if (paid && _paidNumber != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('رقم الدفعة: #$_paidNumber', style: const TextStyle(color: Colors.grey))),
        const SizedBox(height: 16),
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'اسم المستلم', filled: true, fillColor: Color(0xFF161616), border: OutlineInputBorder()), onChanged: (v) async { final list = await p.savedNames(v); if (mounted) setState(() => _suggestions = list); }),
        if (_suggestions.isNotEmpty) Wrap(spacing: 6, children: _suggestions.take(5).map((s) => ActionChip(label: Text(s), onPressed: () => setState(() { _nameCtrl.text = s; _suggestions = []; }))).toList()),
        const SizedBox(height: 12),
        TextField(controller: _amountCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'المبلغ', filled: true, fillColor: Color(0xFF161616), border: OutlineInputBorder())),
        if (paid) ...[
          const SizedBox(height: 12),
          TextField(controller: _commCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'العمولة', filled: true, fillColor: Color(0xFF161616), border: OutlineInputBorder())),
          const SizedBox(height: 8),
          Row(children: [_commBtn(p.comm100.toInt().toString()), const SizedBox(width: 8), _commBtn(p.comm250.toInt().toString())]),
        ],
        const SizedBox(height: 12),
        ListTile(tileColor: const Color(0xFF161616), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), leading: const Icon(Icons.calendar_today), title: Text(fmtDate(_date)), trailing: const Icon(Icons.edit, size: 18), onTap: () async { final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) setState(() => _date = d); }),
      ]),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء'))),
        const SizedBox(width: 10),
        Expanded(child: FilledButton(onPressed: _save, child: const Text('حفظ'))),
      ]))),
    );
  }

  Widget _typeBtn(String label, TransferType t, Color color) {
    final sel = _type == t;
    return SizedBox(height: 50, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: sel ? color : const Color(0xFF161616)), onPressed: () {
      setState(() { _type = t; });
      if (t == TransferType.paid && _commCtrl.text.isEmpty) _commCtrl.text = context.read<AppProvider>().comm100.toString();
      if (t == TransferType.paid) _loadNumber();
    }, child: Text(label)));
  }

  Widget _commBtn(String v) => OutlinedButton(onPressed: () => setState(() => _commCtrl.text = v), child: Text(v));

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (name.isEmpty) return _err('أدخل اسم المستلم');
    if (amount <= 0) return _err('أدخل مبلغاً صحيحاً');
    final p = context.read<AppProvider>();
    final comm = _type == TransferType.paid ? (double.tryParse(_commCtrl.text) ?? 0) : 0.0;
    if (widget.existing == null) {
      final n = _type == TransferType.paid ? await p.nextPaidNumber() : null;
      await p.addTransfer(Transfer(type: _type, recipientName: name, amount: amount, commission: comm, date: _date, accountId: p.selectedAccountId!, paidNumber: n, createdAt: DateTime.now()));
    } else {
      final t = widget.existing!;
      await p.updateTransfer(Transfer(id: t.id, type: _type, recipientName: name, amount: amount, commission: comm, date: _date, accountId: t.accountId, paidNumber: _type == TransferType.paid ? (t.paidNumber ?? await p.nextPaidNumber()) : null, createdAt: t.createdAt));
    }
    if (mounted) Navigator.pop(context);
  }
  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}
EOF

# 13. Accounts Screen
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
        return Card(color: const Color(0xFF161616), child: ListTile(
          leading: const Icon(Icons.account_balance_wallet),
          title: Text(a.name),
          subtitle: Text('افتتاحي: ${fmtNum(a.openingBalance)}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _dialog(context, a)),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _delete(context, a.id!, a.name)),
          ]),
        ));
      }),
      floatingActionButton: FloatingActionButton(onPressed: () => _dialog(context, null), child: const Icon(Icons.add)),
    );
  }

  void _dialog(BuildContext context, Account? a) {
    final nameCtrl = TextEditingController(text: a?.name ?? '');
    final balCtrl = TextEditingController(text: a?.openingBalance.toString() ?? '0');
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text(a == null ? 'حساب جديد' : 'تعديل حساب'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الحساب')),
        TextField(controller: balCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الرصيد الافتتاحي')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
        FilledButton(onPressed: () async {
          final p = context.read<AppProvider>();
          final name = nameCtrl.text.trim();
          if (name.isEmpty) return;
          final bal = double.tryParse(balCtrl.text) ?? 0;
          if (a == null) await p.addAccount(name, bal);
          else await p.updateAccount(Account(id: a.id, name: name, openingBalance: bal, createdAt: a.createdAt));
          if (c.mounted) Navigator.pop(c);
        }, child: const Text('حفظ')),
      ],
    ));
  }

  void _delete(BuildContext context, int id, String name) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('حذف حساب'),
      content: Text('هل تريد حذف "$name" وجميع حوالاته؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await context.read<AppProvider>().deleteAccount(id); if (c.mounted) Navigator.pop(c); }, child: const Text('حذف')),
      ],
    ));
  }
}
EOF

# 14. Settings Screen
cat << 'EOF' > lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(children: [
        _section('العملة'),
        ListTile(title: const Text('العملة الحالية'), trailing: Text(p.currency), onTap: () => _currency(context)),
        _section('العمولات'),
        ListTile(title: const Text('تعديل قيم العمولة'), subtitle: Text('100 = ${p.comm100} • 250 = ${p.comm250}'), onTap: () => _comm(context)),
        _section('الأمان'),
        ListTile(title: const Text('رمز PIN'), trailing: Text(p.hasPin ? 'مفعّل' : 'معطّل'), onTap: () => _pin(context)),
        SwitchListTile(title: const Text('قفل بالبصمة'), value: p.bioEnabled, onChanged: (v) => p.setBio(v)),
        _section('البيانات'),
        ListTile(title: const Text('حذف جميع البيانات'), leading: const Icon(Icons.delete_forever, color: Colors.red), onTap: () => _wipe(context)),
        _section('حول'),
        const ListTile(title: Text('الإصدار'), trailing: Text('2.0')),
        const ListTile(title: Text('المبرمج'), trailing: Text('أدهم الهبة')),
      ]),
    );
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text(t, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)));

  void _currency(BuildContext c) {
    final ctrl = TextEditingController(text: c.read<AppProvider>().currency);
    showDialog(context: c, builder: (ctx) => AlertDialog(title: const Text('العملة'), content: TextField(controller: ctrl), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
      FilledButton(onPressed: () { c.read<AppProvider>().setCurrency(ctrl.text); Navigator.pop(ctx); }, child: const Text('حفظ')),
    ]));
  }

  void _comm(BuildContext c) {
    final p = c.read<AppProvider>();
    final c1 = TextEditingController(text: p.comm100.toString());
    final c2 = TextEditingController(text: p.comm250.toString());
    showDialog(context: c, builder: (ctx) => AlertDialog(title: const Text('العمولات'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: c1, decoration: const InputDecoration(labelText: 'عمولة 100')),
      TextField(controller: c2, decoration: const InputDecoration(labelText: 'عمولة 250')),
    ]), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
      FilledButton(onPressed: () { p.setComms(double.tryParse(c1.text) ?? 0, double.tryParse(c2.text) ?? 0); Navigator.pop(ctx); }, child: const Text('حفظ')),
    ]));
  }

  void _pin(BuildContext c) {
    final p = c.read<AppProvider>();
    if (p.hasPin) { p.removePin(); ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('تم إزالة PIN'))); return; }
    final ctrl = TextEditingController();
    showDialog(context: c, builder: (ctx) => AlertDialog(title: const Text('إنشاء PIN'), content: TextField(controller: ctrl, keyboardType: TextInputType.number, obscureText: true, maxLength: 6), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
      FilledButton(onPressed: () { if (ctrl.text.length >= 4) { p.setPin(ctrl.text); Navigator.pop(ctx); } }, child: const Text('حفظ')),
    ]));
  }

  void _wipe(BuildContext c) {
    showDialog(context: c, builder: (ctx) => AlertDialog(title: const Text('حذف كل البيانات'), content: const Text('سيتم حذف الحسابات والحوالات نهائياً. هل أنت متأكد؟'), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
      FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await c.read<AppProvider>().clearAllData(); if (ctx.mounted) Navigator.pop(ctx); }, child: const Text('حذف')),
    ]));
  }
}
EOF

# 15. GitHub Actions
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
      - name: Checkout
        uses: actions/checkout@v4
      - name: Setup Java 17
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
          channel: 'stable'
          cache: true
      - name: Flutter pub get
        run: flutter pub get
      - name: Build APK (release, debug signing)
        run: flutter build apk --release
      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: app-release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
EOF

echo "✅ تم إنشاء جميع الملفات والأكواد بنجاح!"
echo "⚠️  هام جداً: يجب أن تنشئ مجلد assets وتضع فيه icon.png و splash.png (أو تجاهلها مؤقتاً)."
echo "الخطوة التالية: إذا لم تكن قد فعلت، قم بتشغيل: flutter create ."
echo "ثم: flutter pub get"
echo "ثم: flutter build apk --release"
