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
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddOptions(context), backgroundColor: const Color(0xFF00C853), child: const Icon(Icons.add, color: Colors.white, size: 28)),
    );
  }
  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF161616), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (c) => SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFF00C853), child: Icon(Icons.arrow_downward, color: Colors.white)), title: const Text('حوالة مستلمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), onTap: () { Navigator.pop(c); _add(TransferType.received); }),
      ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFE53935), child: Icon(Icons.arrow_upward, color: Colors.white)), title: const Text('حوالة مدفوعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), onTap: () { Navigator.pop(c); _add(TransferType.paid); }),
    ]))));
  }
  Widget _header(AppProvider p) => Container(margin: const EdgeInsets.fromLTRB(12, 8, 12, 4), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(14)), child: Column(children: [
    Row(children: [const Icon(Icons.account_balance_wallet, color: Colors.white70), const SizedBox(width: 8), Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<int>(value: p.selectedAccountId, isExpanded: true, dropdownColor: const Color(0xFF1F1F1F), hint: const Text('اختر حساباً'), items: p.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(), onChanged: (v) { if (v != null) p.selectAccount(v); })))]),
    const SizedBox(height: 12),
    Row(children: [_stat('الرصيد', p.balance, const Color(0xFF00C853)), _stat('المدفوع', p.totalPaid, const Color(0xFFE53935)), _stat('المستلم', p.totalReceived, Colors.blueAccent), _stat('العدد', p.count.toDouble(), Colors.white70, isCount: true)]),
  ]));
  Widget _stat(String label, double value, Color color, {bool isCount = false}) => Expanded(child: Column(children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)), const SizedBox(height: 4), FittedBox(child: Text(isCount ? value.toInt().toString() : fmtNum(value), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)))]));
  Widget _filters() => Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Row(children: [_chip('الكل', 'all'), const SizedBox(width: 6), _chip('مستلم', 'received'), const SizedBox(width: 6), _chip('مدفوع', 'paid')]));
  Widget _chip(String label, String v) { final sel = _filter == v; return ChoiceChip(label: Text(label), selected: sel, onSelected: (_) => setState(() => _filter = v), backgroundColor: const Color(0xFF161616), selectedColor: Colors.white, labelStyle: TextStyle(color: sel ? Colors.black : Colors.white)); }
  Widget _searchBar() => Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 6), child: TextField(onChanged: (v) => setState(() => _search = v), decoration: InputDecoration(hintText: 'بحث عن اسم...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: const Color(0xFF161616), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 0))));
  Widget _card(Transfer t, AppProvider p) {
    final paid = t.type == TransferType.paid; final color = paid ? const Color(0xFFE53935) : const Color(0xFF00C853);
    return Slidable(key: ValueKey(t.id), endActionPane: ActionPane(motion: const DrawerMotion(), children: [
      SlidableAction(onPressed: (context) => _confirmDelete(context, p, t.id!), backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white, icon: Icons.delete, label: 'حذف', borderRadius: BorderRadius.circular(12)),
      SlidableAction(onPressed: (context) => Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransferScreen(existing: t))).then((_) => p.loadTransfers()), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, icon: Icons.edit, label: 'تعديل', borderRadius: BorderRadius.circular(12)),
    ]), child: Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(12), border: Border(right: BorderSide(color: color, width: 4))), child: ListTile(
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
