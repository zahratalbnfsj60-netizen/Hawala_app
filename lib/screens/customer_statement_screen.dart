import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transfer.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';
import '../utils/exporter.dart';

class CustomerStatementScreen extends StatelessWidget {
  final String customerName;
  const CustomerStatementScreen({super.key, required this.customerName});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final customerTransfers = p.transfers.where((t) => t.recipientName == customerName).toList();
    final totalPaid = customerTransfers.where((t) => t.type == TransferType.paid).fold(0.0, (s, t) => s + t.amount);
    final totalReceived = customerTransfers.where((t) => t.type == TransferType.received).fold(0.0, (s, t) => s + t.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text('كشف حساب: $customerName'), centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => Exporter.exportPDF(customerTransfers, customerName, totalReceived - totalPaid),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF1E1E1E),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            Column(children: [const Text('إجمالي المستلم', style: TextStyle(color: Colors.grey, fontSize: 12)), Text(fmtNum(totalReceived), style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold))]),
            Column(children: [const Text('إجمالي المدفوع', style: TextStyle(color: Colors.grey, fontSize: 12)), Text(fmtNum(totalPaid), style: const TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold))]),
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: customerTransfers.isEmpty ? const Center(child: Text('لا توجد حوالات')) : ListView.builder(
          itemCount: customerTransfers.length,
          itemBuilder: (c, i) {
            final t = customerTransfers[i];
            final paid = t.type == TransferType.paid;
            return ListTile(
              title: Text('${fmtDate(t.date)} ${t.date.hour}:${t.date.minute.toString().padLeft(2, '0')}'),
              subtitle: Text(paid ? 'مدفوع' : 'مستلم', style: TextStyle(color: paid ? const Color(0xFFE53935) : const Color(0xFF00C853))),
              trailing: Text('${fmtNum(t.amount)} ل.س', style: const TextStyle(fontWeight: FontWeight.bold)),
            );
          },
        )),
      ]),
    );
  }
}
