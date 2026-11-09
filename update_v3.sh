#!/bin/bash
echo "🚀 جاري تحديث التطبيق إلى الإصدار 3.0 (واجهات، خطوط، تصدير، وبحث)..."

# 1. تحديث pubspec.yaml
cat << 'EOF' > pubspec.yaml
name: transfer_log
description: سجل الحوالات
publish_to: 'none'
version: 3.0.0+1
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
  google_fonts: ^6.2.0
  local_auth: ^2.2.0
  pdf: ^3.10.8
  printing: ^5.12.0
  share_plus: ^7.2.2
  file_picker: ^8.0.0
  csv: ^6.0.0
  intl: ^0.18.0
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

# 2. تحديث Github Actions
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
          flutter-version: '3.19.0'
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
                  <!-- Needed for pdf printing/sharing -->
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

# 3. تحديث المزود (AppProvider)
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
  bool get needsUnlock => hasPin || bioEnabled;
  void setPin(String pin) { prefs.setString('pin', pin); notifyListeners(); }
  void removePin() { prefs.remove('pin'); notifyListeners(); }
  void setBio(bool v) { prefs.setBool('bio', v); notifyListeners(); }
  bool verifyPin(String pin) => prefs.getString('pin') == pin;
  Future<bool> tryBiometric() async { try { return await _auth.authenticate(localizedReason: 'أدخل بصمتك', options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true)); } catch (_) { return false; } }
  void setUnlocked(bool v) { unlocked = v; notifyListeners(); }

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
  int get count => transfers.length;
  Future<void> clearAllData() async { await _db.clearAll(); accounts = []; transfers = []; selectedAccountId = null; notifyListeners(); }
}
EOF

# 4. أداة التصدير والنسخ الاحتياطي (Exporter)
cat << 'EOF' > lib/utils/exporter.dart
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
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
    await file.writeAsString('\uFEFF$csvData'); // BOM for Arabic Excel support
    await Share.shareXFiles([XFile(path)], text: 'كشف حساب $accountName');
  }

  static Future<void> exportPDF(List<Transfer> transfers, String accountName, double balance) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(level: 0, child: pw.Text('سجل الحوالات - $accountName', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 10),
          pw.Text('الرصيد الحالي: ${fmtNum(balance)}', style: pw.TextStyle(fontSize: 16)),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['التاريخ', 'النوع', 'الاسم', 'المبلغ', 'العمولة'],
            data: transfers.map((t) => [fmtDate(t.date), t.type == TransferType.paid ? 'مدفوع' : 'مستلم', t.recipientName, fmtNum(t.amount), fmtNum(t.commission)]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
            cellAlignment: pw.Alignment.center,
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  static Future<void> backupJSON(String jsonData) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/backup_transfers.json';
    final file = File(path);
    await file.writeAsString(jsonData);
    await Share.shareXFiles([XFile(path)], text: 'نسخة احتياطية للتطبيق');
  }
}
EOF

# 5. الشاشة الرئيسية (تحديث القائمة المنسدلة بالبحث والحدود)
cat << 'EOF' > lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../models/transfer.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';
import 'add_transfer_screen.dart';

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
      appBar: AppBar(title: const Text('سجل الحوالات'), centerTitle: true),
      body: Column(children: [
        _header(p), _filters(), _searchBar(),
        Expanded(child: filtered.isEmpty ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.receipt_long, size: 80, color: Colors.grey), SizedBox(height: 12), Text('لا توجد حوالات بعد', style: TextStyle(color: Colors.grey, fontSize: 16))])) : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 8, 12, 80), itemCount: filtered.length, itemBuilder: (c, i) => _card(filtered[i], p))),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddOptions(context), backgroundColor: p.accentColor, child: const Icon(Icons.add, color: Colors.white, size: 28)),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF161616), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (c) => SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFF00C853), child: const Icon(Icons.arrow_downward, color: Colors.white)), title: const Text('حوالة مستلمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), onTap: () { Navigator.pop(c); _add(TransferType.received); }),
      ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFFE53935), child: const Icon(Icons.arrow_upward, color: Colors.white)), title: const Text('حوالة مدفوعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), onTap: () { Navigator.pop(c); _add(TransferType.paid); }),
    ]))));
  }

  Widget _header(AppProvider p) => Container(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 4), padding: const EdgeInsets.all(12), 
    decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF333333))), 
    child: Column(children: [
      InkWell(
        onTap: () => _showAccountSearch(context, p),
        child: Row(children: [
          const Icon(Icons.account_balance_wallet, color: Colors.white70), const SizedBox(width: 8), 
          Expanded(child: Text(p.selectedAccount?.name ?? 'اختر حساباً', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          const Icon(Icons.arrow_drop_down),
        ]),
      ),
      const Divider(color: Color(0xFF333333), height: 20),
      Row(children: [_stat('الرصيد', p.balance, p.accentColor), _stat('المدفوع', p.totalPaid, const Color(0xFFE53935)), _stat('المستلم', p.totalReceived, Colors.blueAccent), _stat('العدد', p.count.toDouble(), Colors.white70, isCount: true)]),
    ]),
  );

  void _showAccountSearch(BuildContext context, AppProvider p) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => StatefulBuilder(builder: (c, setSt) {
        String q = '';
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: SizedBox(height: 400, child: Column(children: [
            Padding(padding: const EdgeInsets.all(16), child: TextField(
              autofocus: true, decoration: const InputDecoration(hintText: 'ابحث عن حساب...', prefixIcon: Icon(Icons.search)), 
              onChanged: (v) => setSt(() => q = v),
            )),
            Expanded(child: ListView.builder(
              itemCount: p.accounts.where((a) => a.name.contains(q)).length,
              itemBuilder: (c, i) {
                final filtered = p.accounts.where((a) => a.name.contains(q)).toList();
                final a = filtered[i];
                return ListTile(
                  title: Text(a.name), leading: const Icon(Icons.account_balance),
                  trailing: a.id == p.selectedAccountId ? Icon(Icons.check, color: p.accentColor) : null,
                  onTap: () { p.selectAccount(a.id!); Navigator.pop(c); },
                );
              }
            ))
          ])),
        );
      }),
    );
  }

  Widget _stat(String label, double value, Color color, {bool isCount = false}) => Expanded(child: Column(children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)), const SizedBox(height: 4), FittedBox(child: Text(isCount ? value.toInt().toString() : fmtNum(value), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)))]));
  
  Widget _filters() => Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Row(children: [_chip('الكل', 'all'), const SizedBox(width: 6), _chip('مستلم', 'received'), const SizedBox(width: 6), _chip('مدفوع', 'paid')]));
  
  Widget _chip(String label, String v) { final sel = _filter == v; final p = context.watch<AppProvider>(); return ChoiceChip(label: Text(label), selected: sel, onSelected: (_) => setState(() => _filter = v), backgroundColor: const Color(0xFF161616), selectedColor: p.accentColor, labelStyle: TextStyle(color: sel ? Colors.white : Colors.white)); }
  
  Widget _searchBar() => Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 6), child: TextField(onChanged: (v) => setState(() => _search = v), decoration: InputDecoration(hintText: 'بحث عن اسم...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: const Color(0xFF161616), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF333333))), contentPadding: const EdgeInsets.symmetric(vertical: 0))));

  Widget _card(Transfer t, AppProvider p) {
    final paid = t.type == TransferType.paid; final color = paid ? const Color(0xFFE53935) : const Color(0xFF00C853);
    return Slidable(key: ValueKey(t.id), endActionPane: ActionPane(motion: const DrawerMotion(), children: [
      SlidableAction(onPressed: (context) => _confirmDelete(context, p, t.id!), backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white, icon: Icons.delete, label: 'حذف', borderRadius: BorderRadius.circular(12)),
      SlidableAction(onPressed: (context) => Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransferScreen(existing: t))).then((_) => p.loadTransfers()), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, icon: Icons.edit, label: 'تعديل', borderRadius: BorderRadius.circular(12)),
    ]), child: Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(12), border: Border(right: BorderSide(color: color, width: 4), top: const BorderSide(color: Color(0xFF333333)), bottom: const BorderSide(color: Color(0xFF333333)), left: const BorderSide(color: Color(0xFF333333)))), child: ListTile(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransferScreen(existing: t))).then((_) => p.loadTransfers()),
      leading: CircleAvatar(backgroundColor: color.withAlpha(40), child: Icon(paid ? Icons.arrow_upward : Icons.arrow_downward, color: color, size: 20)),
      title: Text(t.recipientName, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${fmtDate(t.date)}${t.paidNumber != null ? " • #${t.paidNumber}" : ""}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${paid ? "-" : "+"}${fmtNum(t.amount)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)), if (t.commission > 0) Text('عمولة: ${fmtNum(t.commission)}', style: const TextStyle(fontSize: 11, color: Colors.grey))]),
    )));
  }
  
  void _confirmDelete(BuildContext context, AppProvider p, int id) {
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text('حذف الحوالة'), content: const Text('هل أنت متأكد من حذف هذه الحوالة؟'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await p.deleteTransfer(id); if (c.mounted) Navigator.pop(c); }, child: const Text('حذف'))]));
  }
  
  void _add(TransferType t) {
    final p = context.read<AppProvider>();
    if (p.selectedAccountId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف حساباً أولاً من شاشة الحسابات'))); return; }
    Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransferScreen(initialType: t))).then((_) => p.loadTransfers());
  }
}
EOF

# 6. شاشة الإضافة والتعديل (أزرار حذف/حفظ/إلغاء وحدود)
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
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'اسم المستلم', filled: true, fillColor: Color(0xFF161616), border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333)))), onChanged: (v) async { final list = await p.savedNames(v); if (mounted) setState(() => _suggestions = list); }),
        if (_suggestions.isNotEmpty) Wrap(spacing: 6, children: _suggestions.take(5).map((s) => ActionChip(label: Text(s), onPressed: () => setState(() { _nameCtrl.text = s; _suggestions = []; }))).toList()),
        const SizedBox(height: 12),
        TextField(controller: _amountCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'المبلغ', filled: true, fillColor: Color(0xFF161616), border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))))),
        if (paid) ...[
          const SizedBox(height: 12),
          TextField(controller: _commCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'العمولة', filled: true, fillColor: Color(0xFF161616), border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))))),
          const SizedBox(height: 8),
          Row(children: [_commBtn(p.comm100.toInt().toString()), const SizedBox(width: 8), _commBtn(p.comm250.toInt().toString())]),
        ],
        const SizedBox(height: 12),
        ListTile(tileColor: const Color(0xFF161616), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFF333333))), leading: const Icon(Icons.calendar_today), title: Text(fmtDate(_date)), trailing: const Icon(Icons.edit, size: 18), onTap: () async { final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) setState(() => _date = d); }),
      ]),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        if (widget.existing != null) Expanded(child: OutlinedButton(onPressed: _confirmDelete, style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text('حذف'))), 
        if (widget.existing != null) const SizedBox(width: 8),
        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء'))), 
        const SizedBox(width: 8), 
        Expanded(child: FilledButton(onPressed: _save, child: const Text('حفظ'))) 
      ]))),
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
    if (widget.existing == null) { final n = _type == TransferType.paid ? await p.nextPaidNumber() : null; await p.addTransfer(Transfer(type: _type, recipientName: name, amount: amount, commission: comm, date: _date, accountId: p.selectedAccountId!, paidNumber: n, createdAt: DateTime.now())); }
    else { final t = widget.existing!; await p.updateTransfer(Transfer(id: t.id, type: _type, recipientName: name, amount: amount, commission: comm, date: _date, accountId: t.accountId, paidNumber: _type == TransferType.paid ? (t.paidNumber ?? await p.nextPaidNumber()) : null, createdAt: t.createdAt)); }
    if (mounted) Navigator.pop(context);
  }
  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}
EOF

# 7. شاشة الإعدادات (تصدير، نسخ احتياطي، خطوط، ألوان)
cat << 'EOF' > lib/screens/settings_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_provider.dart';
import '../utils/exporter.dart';
import '../utils/formatters.dart';

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
        ListTile(title: const Text('نسخ احتياطي (JSON)'), leading: const Icon(Icons.backup), onTap: () {
          final data = {'accounts': p.accounts.map((e) => e.toMap()).toList(), 'transfers': p.transfers.map((e) => e.toMap()).toList()};
          Exporter.backupJSON(jsonEncode(data));
        }),
        
        _section('الأمان'),
        ListTile(title: const Text('رمز PIN'), trailing: Text(p.hasPin ? 'مفعّل' : 'معطّل'), onTap: () => _pin(context)), 
        SwitchListTile(title: const Text('قفل بالبصمة'), value: p.bioEnabled, onChanged: (v) => p.setBio(v)),
        
        _section('البيانات'),
        ListTile(title: const Text('حذف جميع البيانات'), leading: const Icon(Icons.delete_forever, color: Colors.red), onTap: () => _wipe(context)),
        
        _section('حول'),
        const ListTile(title: Text('الإصدار'), trailing: Text('3.0')),
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

# 8. تحديث main.dart لدعم الخطوط
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
              scaffoldBackgroundColor: Colors.black,
              colorScheme: ColorScheme.dark(primary: p.accentColor, secondary: p.accentColor, surface: const Color(0xFF161616), error: const Color(0xFFE53935)),
              textTheme: GoogleFonts.getTextTheme(p.fontFamily, ThemeData.dark().textTheme),
              pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: _NoTransitions()}),
              useMaterial3: true,
              cardTheme: const CardTheme(color: Color(0xFF161616), shape: RoundedRectangleBorder(side: BorderSide(color: Color(0xFF333333)), borderRadius: BorderRadius.all(Radius.circular(12)))),
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

echo "✅ تم تحديث جميع الملفات إلى الإصدار 3.0 بنجاح!"
