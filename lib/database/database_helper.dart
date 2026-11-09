import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/account.dart';
import '../models/transfer.dart';
import '../models/saved_name.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;
  DatabaseHelper._();
  Future<Database> get database async => _db ??= await _initDb();
  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'transfer_log.db');
    return openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('CREATE TABLE accounts(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, openingBalance REAL NOT NULL DEFAULT 0, createdAt TEXT NOT NULL)');
      await db.execute('CREATE TABLE transfers(id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, recipientName TEXT NOT NULL, amount REAL NOT NULL, commission REAL NOT NULL DEFAULT 0, date TEXT NOT NULL, accountId INTEGER NOT NULL, paidNumber INTEGER, createdAt TEXT NOT NULL)');
      await db.execute('CREATE TABLE saved_names(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE NOT NULL, lastUsed TEXT NOT NULL)');
    });
  }
  Future<int> insertAccount(Account a) async => (await database).insert('accounts', a.toMap()..remove('id'));
  Future<void> updateAccount(Account a) async => (await database).update('accounts', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
  Future<void> deleteAccount(int id) async { final db = await database; await db.delete('transfers', where: 'accountId = ?', whereArgs: [id]); await db.delete('accounts', where: 'id = ?', whereArgs: [id]); }
  Future<List<Account>> getAccounts() async { final rows = await (await database).query('accounts', orderBy: 'createdAt ASC'); return rows.map(Account.fromMap).toList(); }
  Future<List<Transfer>> getTransfers(int accountId) async { final rows = await (await database).query('transfers', where: 'accountId = ?', whereArgs: [accountId], orderBy: 'date DESC, id DESC'); return rows.map(Transfer.fromMap).toList(); }
  Future<int> getNextPaidNumber(int accountId) async { final r = await (await database).rawQuery('SELECT MAX(paidNumber) as mx FROM transfers WHERE accountId = ? AND type = "PAID"', [accountId]); final mx = r.first['mx'] as int?; return (mx ?? 0) + 1; }
  Future<int> insertTransfer(Transfer t) async { final db = await database; final id = await db.insert('transfers', t.toMap()..remove('id')); await db.insert('saved_names', {'name': t.recipientName, 'lastUsed': DateTime.now().toIso8601String()}, conflictAlgorithm: ConflictAlgorithm.replace); return id; }
  Future<void> updateTransfer(Transfer t) async => (await database).update('transfers', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  Future<void> deleteTransfer(int id) async => (await database).delete('transfers', where: 'id = ?', whereArgs: [id]);
  Future<void> clearAll() async { final db = await database; await db.delete('transfers'); await db.delete('accounts'); await db.delete('saved_names'); }
  Future<List<String>> getSavedNames({String query = ''}) async { final rows = await (await database).query('saved_names', where: 'name LIKE ?', whereArgs: ['%$query%'], orderBy: 'lastUsed DESC', limit: 8); return rows.map((r) => r['name'] as String).toList(); }
}
