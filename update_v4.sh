#!/bin/bash
echo "🚀 جاري ترقية التطبيق إلى الإصدار الذهبي 4.0..."

# 1. تحديث المزود (AppProvider)
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
  
  // Settings
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

  // Security
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

  // Settings
  void setCurrency(String c) { currency = c; prefs.setString('currency', c); notifyListeners(); }
  void setComms(double c100, double c250) { comm100 = c100; comm250 = c250; prefs.setDouble('comm100', c100); prefs.setDouble('comm250', c250); notifyListeners(); }
  void setFont(String f) { fontFamily = f; prefs.setString('fontFamily', f); notifyListeners(); }
  void setAccentColor(Color c) { accentColor = c; prefs.setInt('accentColor', c.value); notifyListeners(); }

  // Accounts
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

  // Transfers
  Future<void> loadTransfers() async { if (selectedAccountId == null) { transfers = []; return; } transfers = await _db.getTransfers(selectedAccountId!); notifyListeners(); }
  Future<void> addTransfer(Transfer t) async { await _db.insertTransfer(t); await loadTransfers(); }
  Future<void> updateTransfer(Transfer t) async { await _db.updateTransfer(t); await loadTransfers(); }
  Future<void> deleteTransfer(int id) async { await _db.deleteTransfer(id); await loadTransfers(); }
  Future<int> nextPaidNumber() async => await _db.getNextPaidNumber(selectedAccountId ?? 0);
  Future<List<String>> savedNames(String q) => _db.getSavedNames(query: q);

  // Stats
  double get totalReceived => transfers.where((t) => t.type == TransferType.received).fold(0, (s, t) => s + t.amount);
  double get totalPaid => transfers.where((t) => t.type == TransferType.paid).fold(0, (s, t) => s + t.amount);
  double get totalCommission => transfers.where((t) => t.type == TransferType.paid).fold(0, (s, t) => s + t.commission);
  double get balance => (selectedAccount?.openingBalance ?? 0) + totalReceived - totalPaid - totalCommission;
  int get paidCount => transfers.where((t) => t.type == TransferType.paid).length;

  // Backup & Restore
  Future<void> restoreBackup(String jsonStr) async {
    await _db.restoreBackup(jsonStr);
    await loadAccounts();
  }
  Future<void> clearAllData() async { await _db.clearAll(); accounts = []; transfers = []; selectedAccountId = null; notifyListeners(); }
}
EOF

# 2. تحديث قاعدة البيانات لدعم الاستعادة
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

  Future<void> restoreBackup(String jsonStr) async {
    final data = jsonDecode(jsonStr);
    final db = await database;
    await clearAll();
    for (var a in data['accounts']) {
      await db.insert('accounts', a);
    }
    for (var t in data['transfers']) {
      await db.insert('transfers', t);
    }
  }
}
EOF

# 3. أداة التصدير والاستعادة
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
    for (var t in transfers) {
      rows.add([fmtDate(t.date), t.type == TransferType.paid ? 'مدفوع' : 'مستلم', t.recipientName, t.amount, t.commission, t.paidNumber ?? '']);
    }
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
      pw.SizedBox(height: 10),
      pw.Text('الرصيد الحالي: ${fmtNum(balance)}'),
      pw.SizedBox(height: 20),
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
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      return await file.readAsString();
    }
    return null;
  }
}
EOF

# 4. الشاشة الرئيسية (تصميم جدولي، بدون شريط تنقل، شريط إحصائيات سفلي وزرين)
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
  String _filter = 'all';
  String _search = '';
  DateTime? _pausedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedTime != null && DateTime.now().difference(_pausedTime!).inMinutes >= 1) {
        final p = context.read<AppProvider>();
        if (p.autoLock && p.needsUnlock) {
          p.setUnlocked(false);
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LockScreen()));
        }
      }
    }
  }

  void _openSearch() {
    showSearch(context: context, delegate: _TransferSearchDelegate(context.watch<AppProvider>(), _search, (val) => setState(() => _search = val)));
  }

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
        _header(p), _filters(),
        _tableHeader(),
        Expanded(child: filtered.isEmpty ? const Center(child: Text('لا توجد حوالات', style: TextStyle(color: Colors.grey))) : ListView.builder(padding: const EdgeInsets.only(bottom: 16), itemCount: filtered.length, itemBuilder: (c, i) => _row(filtered[i], p))),
      ]),
      bottomNavigationBar: _bottomBar(p),
    );
  }

  Widget _header(AppProvider p) => Container(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 4), padding: const EdgeInsets.all(12), 
    decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF333333))), 
    child: Column(children: [
      Row(children: [
        const Icon(Icons.account_balance_wallet, color: Colors.white70), const SizedBox(width: 8), 
        Expanded(child: Text(p.selectedAccount?.name ?? 'اختر حساباً', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        IconButton(icon: Icon(p.privacyMode ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () => p.togglePrivacy()),
      ]),
      const Divider(color: Color(0xFF333333), height: 20),
      Row(children: [_stat('الرصيد', p.balance, p.accentColor), _stat('المدفوع', p.totalPaid, const Color(0xFFE53935)), _stat('المستلم', p.totalReceived, Colors.blueAccent), _stat('عدد المدفوع', p.paidCount.toDouble(), Colors.white70, isCount: true)]),
    ]),
  );

  Widget _stat(String label, double value, Color color, {bool isCount = false}) {
    final p = context.watch<AppProvider>();
    final display = isCount ? value.toInt().toString() : (p.privacyMode ? '******' : fmtNum(value));
    return Expanded(child: Column(children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)), const SizedBox(height: 4), FittedBox(child: Text(display, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)))]));
  }

  Widget _filters() => Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Row(children: [_chip('الكل', 'all'), const SizedBox(width: 6), _chip('مستلم', 'received'), const SizedBox(width: 6), _chip('مدفوع', 'paid')]));
  Widget _chip(String label, String v) { final sel = _filter == v; final p = context.watch<AppProvider>(); return ChoiceChip(label: Text(label), selected: sel, onSelected: (_) => setState(() => _filter = v), backgroundColor: const Color(0xFF161616), selectedColor: p.accentColor, labelStyle: TextStyle(color: sel ? Colors.white : Colors.white)); }

  Widget _tableHeader() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), color: const Color(0xFF1F1F1F),
    child: const Row(children: [
      Expanded(flex: 3, child: Text('الاسم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
      Expanded(flex: 2, child: Text('التاريخ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
      Expanded(flex: 2, child: Text('مستلم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
      Expanded(flex: 2, child: Text('مدفوع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
    ]),
  );

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
          Expanded(flex: 3, child: Text(t.recipientName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text(fmtDate(t.date), style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text(paid ? '-' : displayAmount, style: TextStyle(fontSize: 12, color: paid ? Colors.transparent : color), textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text(paid ? displayAmount : '-', style: TextStyle(fontSize: 12, color: paid ? color : Colors.transparent), textAlign: TextAlign.center)),
        ]),
      ),
    ));
  }

  Widget _bottomBar(AppProvider p) => Container(
    padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Color(0xFF161616), border: Border(top: BorderSide(color: Color(0xFF333333)))),
    child: SafeArea(child: Row(children: [
      Expanded(child: SizedBox(height: 50, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935)), onPressed: () => _add(TransferType.paid), child: const Text('مدفوع +', style: TextStyle(fontWeight: FontWeight.bold))))),
      const SizedBox(width: 10),
      Expanded(child: SizedBox(height: 50, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00C853)), onPressed: () => _add(TransferType.received), child: const Text('مستلم +', style: TextStyle(fontWeight: FontWeight.bold))))),
    ])),
  );

  void _confirmDelete(BuildContext context, AppProvider p, int id) {
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text('حذف الحوالة'), content: const Text('هل أنت متأكد؟'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await p.deleteTransfer(id); if (c.mounted) Navigator.pop(c); }, child: const Text('حذف'))]));
  }
  
  void _add(TransferType t) {
    final p = context.read<AppProvider>();
    if (p.selectedAccountId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف حساباً أولاً'))); return; }
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

# 5. شاشة الإضافة (تبقى مفتوحة بعد الحفظ + أزرار فوق الكيبورد)
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
    if (widget.existing == null && _type == TransferType.paid) { _commCtrl.text = context.read<AppProvider>().comm100.toString(); }
  }
  
  Future<void> _loadNumber() async { final p = context.read<AppProvider>(); final n = await p.nextPaidNumber(); if (mounted) setState(() => _paidNumber = n); }
  
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>(); final paid = _type == TransferType.paid;
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'حوالة جديدة' : 'تعديل الحوالة')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [Expanded(child: _typeBtn('مستلم', TransferType.received, const Color(0xFF00C853))), const SizedBox(width: 10), Expanded(child: _typeBtn('مدفوع', TransferType.paid, const Color(0xFFE53935)))]),
        if (paid && _paidNumber != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('رقم الدفعة: #$_paidNumber', style: const TextStyle(color: Colors.grey))),
        const SizedBox(height: 16),
        TextField(focusNode: _nameFocus, controller: _nameCtrl, decoration: const InputDecoration(labelText: 'اسم المستلم', filled: true, fillColor: Color(0xFF161616), border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333)))), onChanged: (v) async { final list = await p.savedNames(v); if (mounted) setState(() => _suggestions = list); }, onSubmitted: (_) => _amountFocus.requestFocus()),
        if (_suggestions.isNotEmpty) Wrap(spacing: 6, children: _suggestions.take(5).map((s) => ActionChip(label: Text(s), onPressed: () { setState(() { _nameCtrl.text = s; _suggestions = []; }); _amountFocus.requestFocus(); })).toList()),
        const SizedBox(height: 12),
        TextField(focusNode: _amountFocus, controller: _amountCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'المبلغ', filled: true, fillColor: Color(0xFF161616), border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))))),
        if (paid) ...[
          const SizedBox(height: 12),
          TextField(controller: _commCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'العمولة', filled: true, fillColor: Color(0xFF161616), border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))))),
          const SizedBox(height: 8),
          Row(children: [_commBtn(p.comm100.toInt().toString()), const SizedBox(width: 8), _commBtn(p.comm250.toInt().toString())]),
        ],
        const SizedBox(height: 12),
        ListTile(tileColor: const Color(0xFF161616), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFF333333))), leading: const Icon(Icons.calendar_today), title: Text(fmtDate(_date)), trailing: const Icon(Icons.edit, size: 18), onTap: () async { final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) setState(() => _date = d); }),
      ]),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), // تحريك الأزرار مع الكيبورد
        child: Container(
          padding: const EdgeInsets.all(12), color: const Color(0xFF161616),
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
  
  Widget _typeBtn(String label, TransferType t, Color color) { final sel = _type == t; return SizedBox(height: 50, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: sel ? color : const Color(0xFF161616), side: const BorderSide(color: Color(0xFF333333))), onPressed: () { setState(() { _type = t; }); if (t == TransferType.paid && _commCtrl.text.isEmpty) _commCtrl.text = context.read<AppProvider>().comm100.toString(); if (t == TransferType.paid) _loadNumber(); }, child: Text(label))); }
  
  Widget _commBtn(String v) => OutlinedButton(style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF333333))), onPressed: () => setState(() => _commCtrl.text = v), child: Text(v));
  
  Future<void> _save() async {
    final name = _nameCtrl.text.trim(); final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (name.isEmpty) return _err('أدخل اسم المستلم'); if (amount <= 0) return _err('أدخل مبلغاً صحيحاً');
    HapticFeedback.lightImpact();
    final p = context.read<AppProvider>(); final comm = _type == TransferType.paid ? (double.tryParse(_commCtrl.text) ?? 0) : 0.0;
    
    if (widget.existing == null) { 
      final n = _type == TransferType.paid ? await p.nextPaidNumber() : null; 
      await p.addTransfer(Transfer(type: _type, recipientName: name, amount: amount, commission: comm, date: _date, accountId: p.selectedAccountId!, paidNumber: n, createdAt: DateTime.now()));
      // تفريغ الحقول لإضافة حوالة أخرى
      _nameCtrl.clear(); _amountCtrl.clear(); _suggestions = [];
      if (_type == TransferType.paid) { _commCtrl.text = p.comm100.toString(); _loadNumber(); }
      _nameFocus.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح! يمكنك إضافة حوالة أخرى')));
    } else { 
      final t = widget.existing!; 
      await p.updateTransfer(Transfer(id: t.id, type: _type, recipientName: name, amount: amount, commission: comm, date: _date, accountId: t.accountId, paidNumber: _type == TransferType.paid ? (t.paidNumber ?? await p.nextPaidNumber()) : null, createdAt: t.createdAt)); 
      if (mounted) Navigator.pop(context); 
    }
  }
  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}
EOF

# 6. شاشة الحسابات (إصلاح الخطأ + بحث)
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
        return Card(color: const Color(0xFF161616), shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xFF333333)), borderRadius: BorderRadius.circular(12)), child: ListTile(leading: const Icon(Icons.account_balance_wallet), title: Text(a.name), subtitle: Text('افتتاحي: ${fmtNum(a.openingBalance)}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _dialog(context, a)), IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _delete(context, a.id!, a.name))])));
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

# 7. شاشة الإعدادات (استعادة + إخفاء المبالغ + قفل تلقائي)
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
        const ListTile(title: Text('الإصدار'), trailing: Text('4.0')),
        const ListTile(title: Text('المبرمج'), trailing: Text('أدهم الهبة')),
      ]),
    );
  }
  
  Widget _section(String t) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text(t, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)));
  
  void _font(BuildContext c) {
    showDialog(context: c, builder: (ctx) => SimpleDialog(
      title: const Text('اختر الخط'),
      children: ['Cairo', 'Tajawal', 'Almarai'].map((f) => SimpleDialogOption(onPressed: () { c.read<AppProvider>().setFont(f); Navigator.pop(ctx); }, child: Text(f, style: const TextStyle(fontSize: 18)))).toList(),
    ));
  }
  
  void _color(BuildContext c) {
    showDialog(context: c, builder: (ctx) => AlertDialog(
      title: const Text('اختر اللون الرئيسي'),
      content: Wrap(spacing: 10, children: [Colors.green, Colors.blue, Colors.purple, Colors.orange, Colors.teal, Colors.red].map((col) => GestureDetector(onTap: () { c.read<AppProvider>().setAccentColor(col); Navigator.pop(ctx); }, child: CircleAvatar(backgroundColor: col, radius: 20))).toList()),
    ));
  }

  void _currency(BuildContext c) { final ctrl = TextEditingController(text: c.read<AppProvider>().currency); showDialog(context: c, builder: (ctx) => AlertDialog(title: const Text('العملة'), content: TextField(controller: ctrl), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () { c.read<AppProvider>().setCurrency(ctrl.text); Navigator.pop(ctx); }, child: const Text('حفظ'))])); }
  
  void _comm(BuildContext c) { final p = c.read<AppProvider>(); final c1 = TextEditingController(text: p.comm100.toString()); final c2 = TextEditingController(text: p.comm250.toString()); showDialog(context: c, builder: (ctx) => AlertDialog(title: const Text('العمولات'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: c1, decoration: const InputDecoration(labelText: 'عمولة 100')), TextField(controller: c2, decoration: const InputDecoration(labelText: 'عمولة 250'))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () { p.setComms(double.tryParse(c1.text) ?? 0, double.tryParse(c2.text) ?? 0); Navigator.pop(ctx); }, child: const Text('حفظ'))])); }
  
  void _pin(BuildContext c) { final p = c.read<AppProvider>(); if (p.hasPin) { p.removePin(); ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('تم إزالة PIN'))); return; } final ctrl = TextEditingController(); showDialog(context: c, builder: (ctx) => AlertDialog(title: const Text('إنشاء PIN'), content: TextField(controller: ctrl, keyboardType: TextInputType.number, obscureText: true, maxLength: 6), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () { if (ctrl.text.length >= 4) { p.setPin(ctrl.text); Navigator.pop(ctx); } }, child: const Text('حفظ'))])); }
  
  void _wipe(BuildContext c) { showDialog(context: c, builder: (ctx) => AlertDialog(title: const Text('حذف كل البيانات'), content: const Text('سيتم حذف الحسابات والحوالات نهائياً. هل أنت متأكد؟'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await c.read<AppProvider>().clearAllData(); if (ctx.mounted) Navigator.pop(ctx); }, child: const Text('حذف'))])); }
}
EOF

echo "✅ تم تحديث التطبيق إلى الإصدار الذهبي 4.0 بنجاح!"
