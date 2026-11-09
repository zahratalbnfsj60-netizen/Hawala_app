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
        return Card(color: const Color(0xFF161616), child: ListTile(
          leading: const Icon(Icons.account_balance_wallet),
          title: Text(a.name),
          subtitle: Text('افتتاحي: ${fmtNum(a.openingBalance)}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _dialog(context, a)),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _delete(context, a.id!, a.name)),
          ]),
        ));
      }),
      floatingActionButton: FloatingActionButton(onPressed: () => _dialog(context, null), child: const Icon(Icons.add)),
    );
  }

  void _dialog(BuildContext context, Account? a) {
    final nameCtrl = TextEditingController(text: a?.name ?? '');
    final balCtrl = TextEditingController(text: a?.openingBalance.toString() ?? '0');
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text(a == null ? 'حساب جديد' : 'تعديل حساب'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الحساب')),
        TextField(controller: balCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الرصيد الافتتاحي')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
        FilledButton(onPressed: () async {
          final p = context.read<AppProvider>();
          final name = nameCtrl.text.trim();
          if (name.isEmpty) return;
          final bal = double.tryParse(balCtrl.text) ?? 0;
          if (a == null) await p.addAccount(name, bal);
          else await p.updateAccount(Account(id: a.id, name: name, openingBalance: bal, createdAt: a.createdAt));
          if (c.mounted) Navigator.pop(c);
        }, child: const Text('حفظ')),
      ],
    ));
  }

  void _delete(BuildContext context, int id, String name) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('حذف حساب'),
      content: Text('هل تريد حذف "$name" وجميع حوالاته؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await context.read<AppProvider>().deleteAccount(id); if (c.mounted) Navigator.pop(c); }, child: const Text('حذف')),
      ],
    ));
  }
}
