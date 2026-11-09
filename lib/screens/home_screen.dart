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
