import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transfer.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';

class DailyClosingScreen extends StatelessWidget {
  const DailyClosingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final today = DateTime.now();
    final todayTransfers = p.transfers.where((t) =>
        t.date.year == today.year && t.date.month == today.month && t.date.day == today.day
    ).toList();

    final todayPaid = todayTransfers.where((t) => t.type == TransferType.paid).fold(0.0, (s, t) => s + t.amount);
    final todayReceived = todayTransfers.where((t) => t.type == TransferType.received).fold(0.0, (s, t) => s + t.amount);
    final todayComms = todayTransfers.where((t) => t.type == TransferType.paid).fold(0.0, (s, t) => s + t.commission);
    final net = todayReceived - todayPaid - todayComms;

    return Scaffold(
      appBar: AppBar(title: const Text('الإغلاق اليومي'), centerTitle: true),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('تاريخ اليوم: ${fmtDate(today)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        _card('إجمالي المستلم اليوم', todayReceived, Colors.blueAccent, p.currency),
        _card('إجمالي المدفوع اليوم', todayPaid, const Color(0xFFE53935), p.currency),
        _card('أرباح العمولات اليوم', todayComms, const Color(0xFF00C853), p.currency),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF333333))),
          child: Column(children: [
            const Text('صافي حركة الصندوق اليوم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${fmtNum(net)} ${p.currency}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: net >= 0 ? p.accentColor : const Color(0xFFE53935))),
          ]),
        ),
      ]),
    );
  }

  Widget _card(String title, double value, Color color, String currency) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF333333))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: const TextStyle(fontSize: 16)),
      Text('${fmtNum(value)} $currency', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
    ]),
  );
}
