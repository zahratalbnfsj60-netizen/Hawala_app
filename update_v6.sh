#!/bin/bash
echo "🚀 جاري ترقية التطبيق إلى الإصدار 6.0 (الديون، الجدول، والعملة)..."

mkdir -p lib/models lib/database lib/providers lib/screens lib/utils

# 1. نموذج الدين
cat << 'EOF' > lib/models/debt.dart
class Debt {
  final int? id;
  final String personName;
  final double amount;
  final String type; // 'lend' (سلفة أعطيتها) أو 'borrow' (سلفة أخذتها)
  final DateTime date;
  final bool isSettled;

  Debt({this.id, required this.personName, required this.amount, required this.type, required this.date, this.isSettled = false});

  Map<String, dynamic> toMap() => {
    'id': id, 'personName': personName, 'amount': amount, 'type': type, 'date': date.toIso8601String(), 'isSettled': isSettled ? 1 : 0,
  };

  factory Debt.fromMap(Map<String, dynamic> m) => Debt(
    id: m['id'] as int?, personName: m['personName'] as String, amount: (m['amount'] as num).toDouble(), type: m['type'] as String, date: DateTime.parse(m['date'] as String), isSettled: m['isSettled'] == 1,
  );
}
EOF

# 2. تحديث قاعدة البيانات
cat << 'EOF' > lib/database/database_helper.dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/account.dart';
import '../models/transfer.dart';
import '../models/debt.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;
  DatabaseHelper._();
  Future<Database> get database async => _db ??= await _initDb();
  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'transfer_log.db');
    return openDatabase(path, version: 2, onCreate: (db, v) async {
      await db.execute('CREATE TABLE accounts(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, openingBalance REAL NOT NULL DEFAULT 0, createdAt TEXT NOT NULL)');
      await db.execute('CREATE TABLE transfers(id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, recipientName TEXT NOT NULL, amount REAL NOT NULL, commission REAL NOT NULL DEFAULT 0, date TEXT NOT NULL, accountId INTEGER NOT NULL, paidNumber INTEGER, createdAt TEXT NOT NULL)');
      await db.execute('CREATE TABLE saved_names(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE NOT NULL, lastUsed TEXT NOT NULL)');
      await db.execute('CREATE TABLE debts(id INTEGER PRIMARY KEY AUTOINCREMENT, personName TEXT NOT NULL, amount REAL NOT NULL, type TEXT NOT NULL, date TEXT NOT NULL, isSettled INTEGER NOT NULL DEFAULT 0)');
    }, onUpgrade: (db, oldV, newV) async {
      if (oldV < 2) {
        await db.execute('CREATE TABLE debts(id INTEGER PRIMARY KEY AUTOINCREMENT, personName TEXT NOT NULL, amount REAL NOT NULL, type TEXT NOT NULL, date TEXT NOT NULL, isSettled INTEGER NOT NULL DEFAULT 0)');
      }
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
  Future<void> clearAll() async { final db = await database; await db.delete('transfers'); await db.delete('accounts'); await db.delete('saved_names'); await db.delete('debts'); }
  Future<List<String>> getSavedNames({String query = ''}) async { final rows = await (await database).query('saved_names', where: 'name LIKE ?', whereArgs: ['%$query%'], orderBy: 'lastUsed DESC'); return rows.map((r) => r['name'] as String).toList(); }
  Future<void> restoreBackup(String jsonStr) async { final data = jsonDecode(jsonStr); final db = await database; await clearAll(); for (var a in data['accounts']) { await db.insert('accounts', a); } for (var t in data['transfers']) { await db.insert('transfers', t); } }

  // Debts
  Future<List<Debt>> getDebts() async { final rows = await (await database).query('debts', orderBy: 'date DESC'); return rows.map(Debt.fromMap).toList(); }
  Future<int> insertDebt(Debt d) async => (await database).insert('debts', d.toMap()..remove('id'));
  Future<void> updateDebt(Debt d) async => (await database).update('debts', d.toMap(), where: 'id = ?', whereArgs: [d.id]);
  Future<void> deleteDebt(int id) async => (await database).delete('debts', where: 'id = ?', whereArgs: [id]);
}
EOF

# 3. تحديث المزود (AppProvider)
cat << 'EOF' > lib/providers/app_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/transfer.dart';
import '../models/debt.dart';

class AppProvider extends ChangeNotifier {
  final SharedPreferences prefs;
  AppProvider(this.prefs);
  final DatabaseHelper _db = DatabaseHelper.instance;
  final LocalAuthentication _auth = LocalAuthentication();
  
  List<Account> accounts = [];
  List<Transfer> transfers = [];
  List<Debt> debts = [];
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
    await loadDebts();
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
  Future<List<String>> savedNames() => _db.getSavedNames();

  double get totalReceived => transfers.where((t) => t.type == TransferType.received).fold(0, (s, t) => s + t.amount);
  double get totalPaid => transfers.where((t) => t.type == TransferType.paid).fold(0, (s, t) => s + t.amount);
  double get totalCommission => transfers.where((t) => t.type == TransferType.paid).fold(0, (s, t) => s + t.commission);
  double get balance => (selectedAccount?.openingBalance ?? 0) + totalReceived - totalPaid - totalCommission;
  int get paidCount => transfers.where((t) => t.type == TransferType.paid).length;

  // Debts
  Future<void> loadDebts() async { debts = await _db.getDebts(); notifyListeners(); }
  int get unsettledDebtsCount => debts.where((d) => !d.isSettled).length;
  Future<void> addDebt(Debt d) async { await _db.insertDebt(d); await loadDebts(); }
  Future<void> updateDebt(Debt d) async { await _db.updateDebt(d); await loadDebts(); }
  Future<void> deleteDebt(int id) async { await _db.deleteDebt(id); await loadDebts(); }

  Future<void> restoreBackup(String jsonStr) async { await _db.restoreBackup(jsonStr); await loadAccounts(); await loadDebts(); }
  Future<void> clearAllData() async { await _db.clearAll(); accounts = []; transfers = []; debts = []; selectedAccountId = null; notifyListeners(); }
}
EOF

# 4. الشاشة الرئيسية (تحديث الجدول، العملة، العدادات، والديون)
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
import 'debts_screen.dart';
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
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(icon: const Icon(Icons.handshake), tooltip: 'الديون', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtsScreen()))),
              if (p.unsettledDebtsCount > 0) Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('${p.unsettledDebtsCount}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
            ],
          ),
          IconButton(icon: const Icon(Icons.pie_chart), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()))),
          IconButton(icon: const Icon(Icons.people), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen())).then((_) => p.loadAccounts())),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
      body: Column(children: [
        _accountHeader(p), _dateFilters(), _tableHeader(),
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
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFF333333), borderRadius: BorderRadius.circular(12)),
        child: Text('${p.paidCount} مدفوع', style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ),
      const SizedBox(width: 8),
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

  Widget _tableHeader() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), color: const Color(0xFF161616),
    child: const Row(children: [
      Expanded(flex: 3, child: Text('الاسم والتاريخ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
      Expanded(flex: 2, child: Text('مستلم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey), textAlign: TextAlign.center)),
      Expanded(flex: 2, child: Text('مدفوع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey), textAlign: TextAlign.center)),
    ]),
  );

  Widget _row(Transfer t, AppProvider p) {
    final paid = t.type == TransferType.paid;
    final color = paid ? const Color(0xFFE53935) : const Color(0xFF00C853);
    final displayAmount = p.privacyMode ? '***' : '${fmtNum(t.amount)} ل.س';

    return Slidable(key: ValueKey(t.id), endActionPane: ActionPane(motion: const DrawerMotion(), children: [
      SlidableAction(onPressed: (c) => _confirmDelete(c, p, t.id!), backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white, icon: Icons.delete, label: 'حذف'),
      SlidableAction(onPressed: (c) => Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransferScreen(existing: t))).then((_) => p.loadTransfers()), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, icon: Icons.edit, label: 'تعديل'),
    ]), child: InkWell(
      onTap: () => _showDetails(t, p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF333333)))),
        child: Row(children: [
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.recipientName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Text('${fmtDate(t.date)} ${t.date.hour.toString().padLeft(2, '0')}:${t.date.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ])),
          Expanded(flex: 2, child: Text(paid ? '-' : displayAmount, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: paid ? Colors.transparent : color), textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text(paid ? displayAmount : '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: paid ? color : Colors.transparent), textAlign: TextAlign.center)),
        ]),
      ),
    ));
  }

  void _showDetails(Transfer t, AppProvider p) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text(t.recipientName),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('التاريخ: ${fmtDate(t.date)} ${t.date.hour}:${t.date.minute.toString().padLeft(2, '0')}'),
        Text('المبلغ: ${fmtNum(t.amount)} ل.س'),
        Text('العمولة: ${fmtNum(t.commission)} ل.س'),
        Text('النوع: ${t.type == TransferType.paid ? 'مدفوع' : 'مستلم'}'),
        if (t.paidNumber != null) Text('رقم الدفعة: #${t.paidNumber}'),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إغلاق'))],
    ));
  }

  Widget _bottomStatsAndActions(AppProvider p) => Container(
    padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Color(0xFF1E1E1E), border: Border(top: BorderSide(color: Color(0xFF333333)))),
    child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        _stat('الرصيد', p.balance, p.accentColor), 
        _stat('المدفوع', p.totalPaid, const Color(0xFFE53935)), 
        _stat('المستلم', p.totalReceived, Colors.blueAccent), 
        _stat('العمولات', p.totalCommission, Colors.orangeAccent),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: SizedBox(height: 45, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935)), onPressed: () => _add(TransferType.paid), child: const Text('مدفوع +', style: TextStyle(fontWeight: FontWeight.bold))))),
        const SizedBox(width: 10),
        Expanded(child: SizedBox(height: 45, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00C853)), onPressed: () => _add(TransferType.received), child: const Text('مستلم +', style: TextStyle(fontWeight: FontWeight.bold))))),
      ]),
    ])),
  );

  Widget _stat(String label, double value, Color color) {
    final p = context.watch<AppProvider>();
    final display = p.privacyMode ? '***' : fmtNum(value);
    return Expanded(child: Column(children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)), const SizedBox(height: 2), FittedBox(child: Text(display, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)))]));
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

# 5. شاشة الإضافة (Autocomplete + تصميم بطاقات)
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
  late TransferType _type; DateTime _date = DateTime.now(); List<String> _savedNames = []; int? _paidNumber;
  final FocusNode _amountFocus = FocusNode();
  
  @override
  void initState() {
    super.initState();
    _fetchNames();
    if (widget.existing != null) { final t = widget.existing!; _type = t.type; _nameCtrl.text = t.recipientName; _amountCtrl.text = t.amount.toString(); _commCtrl.text = t.commission.toString(); _date = t.date; _paidNumber = t.paidNumber; }
    else { _type = widget.initialType ?? TransferType.paid; _loadNumber(); }
  }

  Future<void> _fetchNames() async { final p = context.read<AppProvider>(); final names = await p.savedNames(); if (mounted) setState(() => _savedNames = names); }
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
            title: Text('${fmtDate(_date)} - ${_date.hour.toString().padLeft(2, '0')}:${_date.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 14)),
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
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) return _savedNames;
              return _savedNames.where((String option) => option.contains(textEditingValue.text));
            },
            onSelected: (String selection) { _nameCtrl.text = selection; _amountFocus.requestFocus(); },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              return Card(child: TextField(focusNode: focusNode, controller: controller, decoration: const InputDecoration(labelText: 'اسم المستلم', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)), onChanged: (v) => _nameCtrl.text = v, onSubmitted: (_) => onFieldSubmitted()));
            },
          ),
          const SizedBox(height: 12),
          Card(child: TextField(focusNode: _amountFocus, controller: _amountCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'المبلغ (ل.س)', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)), onChanged: _onAmountChanged)),
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
      _nameCtrl.clear(); _amountCtrl.clear();
      if (_type == TransferType.paid) { _loadNumber(); _commCtrl.clear(); }
      _amountFocus.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح!')));
      _fetchNames();
    } else { 
      final t = widget.existing!; 
      await p.updateTransfer(Transfer(id: t.id, type: _type, recipientName: name, amount: amount, commission: comm, date: _date, accountId: t.accountId, paidNumber: _type == TransferType.paid ? (t.paidNumber ?? await p.nextPaidNumber()) : null, createdAt: t.createdAt)); 
      if (mounted) Navigator.pop(context); 
    }
  }
  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}
EOF

# 6. شاشة الديون (الجديدة)
cat << 'EOF' > lib/screens/debts_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/debt.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';

class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('سجل الديون (السلف)'), centerTitle: true),
      body: p.debts.isEmpty ? const Center(child: Text('لا توجد ديون مسجلة', style: TextStyle(color: Colors.grey))) : ListView.builder(padding: const EdgeInsets.all(12), itemCount: p.debts.length, itemBuilder: (c, i) {
        final d = p.debts[i];
        final isLend = d.type == 'lend';
        final color = d.isSettled ? Colors.grey : (isLend ? const Color(0xFF00C853) : const Color(0xFFE53935));
        return Card(
          child: ListTile(
            leading: CircleAvatar(backgroundColor: color.withAlpha(40), child: Icon(isLend ? Icons.arrow_upward : Icons.arrow_downward, color: color)),
            title: Text(d.personName, style: TextStyle(fontWeight: FontWeight.bold, decoration: d.isSettled ? TextDecoration.lineThrough : null)),
            subtitle: Text('${fmtDate(d.date)} • ${isLend ? "أعطيت سلفة" : "أخذت سلفة"}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${fmtNum(d.amount)} ل.س', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Checkbox(value: d.isSettled, onChanged: (v) { d.isSettled = v ?? false; p.updateDebt(d); }),
              IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => p.deleteDebt(d.id!)),
            ]),
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(onPressed: () => _addDebt(context), backgroundColor: p.accentColor, child: const Icon(Icons.add)),
    );
  }

  void _addDebt(BuildContext context) {
    final nameCtrl = TextEditingController(); final amountCtrl = TextEditingController(); String type = 'lend';
    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setSt) => AlertDialog(
      title: const Text('إضافة دين / سلفة'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'lend', label: Text('أعطيت')), ButtonSegment(value: 'borrow', label: Text('أخذت'))],
          selected: {type}, onSelectionChanged: (v) => setSt(() => type = v.first),
        ),
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الشخص')),
        TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
        FilledButton(onPressed: () {
          if (nameCtrl.text.isNotEmpty && amountCtrl.text.isNotEmpty) {
            context.read<AppProvider>().addDebt(Debt(personName: nameCtrl.text, amount: double.parse(amountCtrl.text), type: type, date: DateTime.now()));
            Navigator.pop(c);
          }
        }, child: const Text('حفظ')),
      ],
    )));
  }
}
EOF

echo "✅ تم تحديث التطبيق إلى الإصدار 6.0 بنجاح!"
