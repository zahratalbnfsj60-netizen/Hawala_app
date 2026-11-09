class Account {
  final int? id;
  final String name;
  final double openingBalance;
  final DateTime createdAt;
  Account({this.id, required this.name, required this.openingBalance, required this.createdAt});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'openingBalance': openingBalance, 'createdAt': createdAt.toIso8601String()};
  factory Account.fromMap(Map<String, dynamic> m) => Account(id: m['id'] as int?, name: m['name'] as String, openingBalance: (m['openingBalance'] as num).toDouble(), createdAt: DateTime.parse(m['createdAt'] as String));
}
