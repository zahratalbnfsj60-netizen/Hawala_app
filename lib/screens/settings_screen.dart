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
