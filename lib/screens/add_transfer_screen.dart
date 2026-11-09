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
