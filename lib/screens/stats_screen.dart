import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final total = p.totalPaid + p.totalReceived;
    final paidPercent = total == 0 ? 0.0 : (p.totalPaid / total) * 100;
    final recPercent = total == 0 ? 0.0 : (p.totalReceived / total) * 100;
    return Scaffold(
      appBar: AppBar(title: const Text('الإحصائيات'), centerTitle: true),
      body: p.transfers.length == 0
          ? const Center(child: Text('لا توجد بيانات كافية', style: TextStyle(color: Colors.grey)))
          : ListView(padding: const EdgeInsets.all(16), children: [
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16)), child: Column(children: [
                const Text('نسبة المدفوع إلى المستلم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                SizedBox(height: 200, child: PieChart(PieChartData(sectionsSpace: 4, centerSpaceRadius: 60, sections: [
                  PieChartSectionData(color: const Color(0xFFE53935), value: paidPercent, title: '${paidPercent.toStringAsFixed(1)}%', radius: 50, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(color: const Color(0xFF00C853), value: recPercent, title: '${recPercent.toStringAsFixed(1)}%', radius: 50, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ]))),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _legend(const Color(0xFFE53935), 'المدفوع: ${fmtNum(p.totalPaid)}'),
                  const SizedBox(width: 16),
                  _legend(const Color(0xFF00C853), 'المستلم: ${fmtNum(p.totalReceived)}'),
                ]),
              ])),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _card('إجمالي الحوالات', p.transfers.length.toString(), Icons.swap_horiz, Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _card('إجمالي العمولات', fmtNum(p.totalCommission), Icons.monetization_on, Colors.orange)),
              ]),
            ]),
    );
  }
  Widget _legend(Color color, String text) => Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(text, style: const TextStyle(fontSize: 12))]);
  Widget _card(String title, String value, IconData icon, Color color) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color), const SizedBox(height: 12), Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]));
}
