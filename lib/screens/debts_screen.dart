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
              IconButton(icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20), onPressed: () => _addDebt(context, d)),
              IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => p.deleteDebt(d.id!)),
            ]),
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(onPressed: () => _addDebt(context, null), backgroundColor: p.accentColor, child: const Icon(Icons.add)),
    );
  }

  void _addDebt(BuildContext context, Debt? debt) {
    final nameCtrl = TextEditingController(text: debt?.personName ?? ''); 
    final amountCtrl = TextEditingController(text: debt?.amount.toString() ?? ''); 
    String type = debt?.type ?? 'lend';
    
    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setSt) => AlertDialog(
      title: Text(debt == null ? 'إضافة دين / سلفة' : 'تعديل الدين'),
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
            final provider = context.read<AppProvider>();
            if (debt == null) {
              provider.addDebt(Debt(personName: nameCtrl.text, amount: double.parse(amountCtrl.text), type: type, date: DateTime.now()));
            } else {
              provider.updateDebt(Debt(id: debt.id, personName: nameCtrl.text, amount: double.parse(amountCtrl.text), type: type, date: debt.date, isSettled: debt.isSettled));
            }
            Navigator.pop(c);
          }
        }, child: const Text('حفظ')),
      ],
    )));
  }
}
