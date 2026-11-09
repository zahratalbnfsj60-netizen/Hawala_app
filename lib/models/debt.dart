class Debt {
  final int? id;
  final String personName;
  final double amount;
  final String type; // 'lend' (سلفة أعطيتها) أو 'borrow' (سلفة أخذتها)
  final DateTime date;
  bool isSettled;

  Debt({this.id, required this.personName, required this.amount, required this.type, required this.date, this.isSettled = false});

  Map<String, dynamic> toMap() => {
    'id': id, 'personName': personName, 'amount': amount, 'type': type, 'date': date.toIso8601String(), 'isSettled': isSettled ? 1 : 0,
  };

  factory Debt.fromMap(Map<String, dynamic> m) => Debt(
    id: m['id'] as int?, personName: m['personName'] as String, amount: (m['amount'] as num).toDouble(), type: m['type'] as String, date: DateTime.parse(m['date'] as String), isSettled: m['isSettled'] == 1,
  );
}
