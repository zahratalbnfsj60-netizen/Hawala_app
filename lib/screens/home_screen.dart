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
