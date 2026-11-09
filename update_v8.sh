#!/bin/bash
echo "🚀 جاري ترقية التطبيق إلى الإصدار التجاري 8.0..."

# 1. تحديث رقم الإصدار في pubspec.yaml (لحل مشكلة التثبيت وإجبار التحديث)
sed -i 's/version: 6.0.0+1/version: 8.0.0+8/' pubspec.yaml

# 2. إنشاء ملف منسق الأرقام
cat << 'EOF' > lib/utils/number_formatter.dart
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class NumberTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final int newTextValue = int.parse(newValue.text.replaceAll(',', ''));
    final String newText = NumberFormat.decimalPattern('en').format(newTextValue);
    return TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}
EOF

# 3. إنشاء شاشة كشف حساب العميل
cat << 'EOF' > lib/screens/customer_statement_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transfer.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';
import '../utils/exporter.dart';

class CustomerStatementScreen extends StatelessWidget {
  final String customerName;
  const CustomerStatementScreen({super.key, required this.customerName});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final customerTransfers = p.transfers.where((t) => t.recipientName == customerName).toList();
    final totalPaid = customerTransfers.where((t) => t.type == TransferType.paid).fold(0.0, (s, t) => s + t.amount);
    final totalReceived = customerTransfers.where((t) => t.type == TransferType.received).fold(0.0, (s, t) => s + t.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text('كشف حساب: $customerName'), centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => Exporter.exportPDF(customerTransfers, customerName, totalReceived - totalPaid),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF1E1E1E),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            Column(children: [const Text('إجمالي المستلم', style: TextStyle(color: Colors.grey, fontSize: 12)), Text(fmtNum(totalReceived), style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold))]),
            Column(children: [const Text('إجمالي المدفوع', style: TextStyle(color: Colors.grey, fontSize: 12)), Text(fmtNum(totalPaid), style: const TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold))]),
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: customerTransfers.isEmpty ? const Center(child: Text('لا توجد حوالات')) : ListView.builder(
          itemCount: customerTransfers.length,
          itemBuilder: (c, i) {
            final t = customerTransfers[i];
            final paid = t.type == TransferType.paid;
            return ListTile(
              title: Text('${fmtDate(t.date)} ${t.date.hour}:${t.date.minute.toString().padLeft(2, '0')}'),
              subtitle: Text(paid ? 'مدفوع' : 'مستلم', style: TextStyle(color: paid ? const Color(0xFFE53935) : const Color(0xFF00C853))),
              trailing: Text('${fmtNum(t.amount)} ل.س', style: const TextStyle(fontWeight: FontWeight.bold)),
            );
          },
        )),
      ]),
    );
  }
}
EOF

# 4. تحديث الشاشة الرئيسية (ربط شاشة العميل بالبحث)
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
import 'daily_closing_screen.dart';
import 'customer_statement_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String _dateFilter = 'all';
  String _sortBy = 'date_desc';
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
    
    var filtered = p.transfers.where((t) {
      if (_search.isNotEmpty && !t.recipientName.contains(_search)) return false;
      if (_dateFilter == 'today' && t.date.isBefore(today)) return false;
      if (_dateFilter == 'week' && t.date.isBefore(today.subtract(const Duration(days: 7)))) return false;
      if (_dateFilter == 'month' && (t.date.year != now.year || t.date.month != now.month)) return false;
      if (_dateFilter == 'year' && t.date.year != now.year) return false;
      return true;
    }).toList();

    if (_sortBy == 'date_desc') filtered.sort((a, b) => b.date.compareTo(a.date));
    if (_sortBy == 'date_asc') filtered.sort((a, b) => a.date.compareTo(b.date));
    if (_sortBy == 'amount_desc') filtered.sort((a, b) => b.amount.compareTo(a.amount));
    if (_sortBy == 'amount_asc') filtered.sort((a, b) => a.amount.compareTo(b.amount));

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الحوالات'), centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _openSearch),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (val) => setState(() => _sortBy = val),
            itemBuilder: (c) => [
              const PopupMenuItem(value: 'date_desc', child: Text('الأحدث أولاً')),
              const PopupMenuItem(value: 'date_asc', child: Text('الأقدم أولاً')),
              const PopupMenuItem(value: 'amount_desc', child: Text('الأعلى مبلغاً')),
              const PopupMenuItem(value: 'amount_asc', child: Text('الأقل مبلغاً')),
            ],
          ),
          IconButton(icon: const Icon(Icons.today), tooltip: 'الإغلاق اليومي', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyClosingScreen()))),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(icon: const Icon(Icons.handshake), tooltip: 'الديون', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtsScreen()))),
              if (p.unsettledDebtsCount > 0) Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('${p.unsettledDebtsCount}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
            ],
          ),
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
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerStatementScreen(customerName: t.recipientName))),
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
    final names = p.transfers.map((t) => t.recipientName).toSet().where((n) => n.contains(query)).toList();
    return ListView.builder(
      itemCount: names.length,
      itemBuilder: (c, i) => ListTile(
        leading: const Icon(Icons.person),
        title: Text(names[i]),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerStatementScreen(customerName: names[i])));
        },
      ),
    );
  }
}
EOF

# 5. تحديث شاشة إضافة الحوالة (تنسيق الأرقام + الآلة الحاسبة)
cat << 'EOF' > lib/screens/add_transfer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/transfer.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';
import '../utils/number_formatter.dart';

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
    if (widget.existing != null) { final t = widget.existing!; _type = t.type; _nameCtrl.text = t.recipientName; _amountCtrl.text = fmtNum(t.amount); _commCtrl.text = fmtNum(t.commission); _date = t.date; _paidNumber = t.paidNumber; }
    else { _type = widget.initialType ?? TransferType.paid; _loadNumber(); }
  }

  Future<void> _fetchNames() async { final p = context.read<AppProvider>(); final names = await p.savedNames(); if (mounted) setState(() => _savedNames = names); }
  Future<void> _loadNumber() async { final p = context.read<AppProvider>(); final n = await p.nextPaidNumber(); if (mounted) setState(() => _paidNumber = n); }

  void _onAmountChanged(String val) {
    if (_type != TransferType.paid) return;
    final amount = double.tryParse(val.replaceAll(',', '')) ?? 0;
    if (amount >= 2000 && amount < 100000) { _commCtrl.text = '100'; } 
    else if (amount >= 100000) { _commCtrl.text = '250'; } 
    else { _commCtrl.text = '0'; }
  }

  void _openCalculator() async {
    final result = await showDialog<double>(context: context, builder: (c) => const CalculatorDialog());
    if (result != null) {
      _amountCtrl.text = fmtNum(result);
      _onAmountChanged(_amountCtrl.text);
    }
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
          Card(child: TextField(
            focusNode: _amountFocus, controller: _amountCtrl, keyboardType: TextInputType.number, 
            inputFormatters: [NumberTextInputFormatter()], 
            decoration: InputDecoration(
              labelText: 'المبلغ (ل.س)', border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: IconButton(icon: const Icon(Icons.calculate, color: Colors.blueAccent), onPressed: _openCalculator),
            ), 
            onChanged: _onAmountChanged,
          )),
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
    final name = _nameCtrl.text.trim(); 
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    if (name.isEmpty) return _err('أدخل اسم المستلم'); if (amount <= 0) return _err('أدخل مبلغاً صحيحاً');
    HapticFeedback.lightImpact();
    final p = context.read<AppProvider>(); final comm = _type == TransferType.paid ? (double.tryParse(_commCtrl.text.replaceAll(',', '')) ?? 0) : 0.0;
    
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

// آلة حاسبة مدمجة
class CalculatorDialog extends StatefulWidget {
  const CalculatorDialog({super.key});
  @override
  State<CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<CalculatorDialog> {
  final _ctrl1 = TextEditingController();
  final _ctrl2 = TextEditingController();
  bool _isAddition = true;

  void _calculate() {
    final v1 = double.tryParse(_ctrl1.text) ?? 0;
    final v2 = double.tryParse(_ctrl2.text) ?? 0;
    Navigator.pop(context, _isAddition ? v1 + v2 : v1 - v2);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('الآلة الحاسبة'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _ctrl1, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الرقم الأول')),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ChoiceChip(label: const Text('+', style: TextStyle(fontSize: 20)), selected: _isAddition, onSelected: (v) => setState(() => _isAddition = true)),
          const SizedBox(width: 10),
          ChoiceChip(label: const Text('-', style: TextStyle(fontSize: 20)), selected: !_isAddition, onSelected: (v) => setState(() => _isAddition = false)),
        ]),
        TextField(controller: _ctrl2, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الرقم الثاني')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _calculate, child: const Text('موافق')),
      ],
    );
  }
}
EOF

echo "✅ تم التحديث بنجاح إلى الإصدار 8.0!"
