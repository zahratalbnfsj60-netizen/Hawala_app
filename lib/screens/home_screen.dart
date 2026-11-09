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
