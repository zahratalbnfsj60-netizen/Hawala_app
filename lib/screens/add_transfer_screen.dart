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
