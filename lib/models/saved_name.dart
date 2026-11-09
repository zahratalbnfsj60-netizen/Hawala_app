class SavedName {
  final int? id; final String name; final DateTime lastUsed;
  SavedName({this.id, required this.name, required this.lastUsed});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'lastUsed': lastUsed.toIso8601String()};
}
