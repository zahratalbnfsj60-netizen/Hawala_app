enum TransferType { paid, received }
class Transfer {
  final int? id; final TransferType type; final String recipientName; final double amount; final double commission; final DateTime date; final int accountId; final int? paidNumber; final DateTime createdAt;
  Transfer({this.id, required this.type, required this.recipientName, required this.amount, required this.commission, required this.date, required this.accountId, this.paidNumber, required this.createdAt});
  Map<String, dynamic> toMap() => {'id': id, 'type': type == TransferType.paid ? 'PAID' : 'RECEIVED', 'recipientName': recipientName, 'amount': amount, 'commission': commission, 'date': date.toIso8601String(), 'accountId': accountId, 'paidNumber': paidNumber, 'createdAt': createdAt.toIso8601String()};
  factory Transfer.fromMap(Map<String, dynamic> m) => Transfer(id: m['id'] as int?, type: (m['type'] as String) == 'PAID' ? TransferType.paid : TransferType.received, recipientName: m['recipientName'] as String, amount: (m['amount'] as num).toDouble(), commission: (m['commission'] as num).toDouble(), date: DateTime.parse(m['date'] as String), accountId: m['accountId'] as int, paidNumber: m['paidNumber'] as int?, createdAt: DateTime.parse(m['createdAt'] as String));
}
