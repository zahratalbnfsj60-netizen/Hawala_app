import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/transfer.dart';
import '../models/debt.dart';

class AppProvider extends ChangeNotifier {
  final SharedPreferences prefs;
  AppProvider(this.prefs);
  final DatabaseHelper _db = DatabaseHelper.instance;
  final LocalAuthentication _auth = LocalAuthentication();
  
  List<Account> accounts = [];
  List<Transfer> transfers = [];
  List<Debt> debts = [];
  int? selectedAccountId;
  bool loading = true;
  bool unlocked = false;
  bool privacyMode = false;
  
  String currency = 'ل.س';
  double comm100 = 100;
  double comm250 = 250;
  String fontFamily = 'Cairo';
  Color accentColor = const Color(0xFF00C853);

  Future<void> init() async {
    currency = prefs.getString('currency') ?? 'ل.س';
    comm100 = prefs.getDouble('comm100') ?? 100;
    comm250 = prefs.getDouble('comm250') ?? 250;
    fontFamily = prefs.getString('fontFamily') ?? 'Cairo';
    accentColor = Color(prefs.getInt('accentColor') ?? 0xFF00C853);
    await loadAccounts();
    await loadDebts();
    loading = false;
    notifyListeners();
  }

  bool get hasPin => prefs.getString('pin') != null;
  bool get bioEnabled => prefs.getBool('bio') ?? false;
  bool get autoLock => prefs.getBool('autoLock') ?? true;
  bool get needsUnlock => hasPin || bioEnabled;
  void setPin(String pin) { prefs.setString('pin', pin); notifyListeners(); }
  void removePin() { prefs.remove('pin'); notifyListeners(); }
  void setBio(bool v) { prefs.setBool('bio', v); notifyListeners(); }
  void setAutoLock(bool v) { prefs.setBool('autoLock', v); notifyListeners(); }
  bool verifyPin(String pin) => prefs.getString('pin') == pin;
  Future<bool> tryBiometric() async { try { return await _auth.authenticate(localizedReason: 'أدخل بصمتك', options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true)); } catch (_) { return false; } }
  void setUnlocked(bool v) { unlocked = v; notifyListeners(); }
  void togglePrivacy() { privacyMode = !privacyMode; notifyListeners(); }

  void setCurrency(String c) { currency = c; prefs.setString('currency', c); notifyListeners(); }
  void setComms(double c100, double c250) { comm100 = c100; comm250 = c250; prefs.setDouble('comm100', c100); prefs.setDouble('comm250', c250); notifyListeners(); }
  void setFont(String f) { fontFamily = f; prefs.setString('fontFamily', f); notifyListeners(); }
  void setAccentColor(Color c) { accentColor = c; prefs.setInt('accentColor', c.value); notifyListeners(); }

  Future<void> loadAccounts() async {
    accounts = await _db.getAccounts();
    if (accounts.isNotEmpty) {
      if (selectedAccountId == null || !accounts.any((a) => a.id == selectedAccountId)) { selectedAccountId = accounts.first.id; }
      await loadTransfers();
    } else { transfers = []; }
    notifyListeners();
  }
  Account? get selectedAccount => accounts.where((a) => a.id == selectedAccountId).firstOrNull;
  Future<void> selectAccount(int id) async { selectedAccountId = id; await loadTransfers(); notifyListeners(); }
  Future<void> addAccount(String name, double opening) async { await _db.insertAccount(Account(name: name, openingBalance: opening, createdAt: DateTime.now())); await loadAccounts(); }
  Future<void> updateAccount(Account a) async { await _db.updateAccount(a); await loadAccounts(); }
  Future<void> deleteAccount(int id) async { await _db.deleteAccount(id); if (selectedAccountId == id) selectedAccountId = null; await loadAccounts(); }

  Future<void> loadTransfers() async { if (selectedAccountId == null) { transfers = []; return; } transfers = await _db.getTransfers(selectedAccountId!); notifyListeners(); }
  Future<void> addTransfer(Transfer t) async { await _db.insertTransfer(t); await loadTransfers(); }
  Future<void> updateTransfer(Transfer t) async { await _db.updateTransfer(t); await loadTransfers(); }
  Future<void> deleteTransfer(int id) async { await _db.deleteTransfer(id); await loadTransfers(); }
  Future<int> nextPaidNumber() async => await _db.getNextPaidNumber(selectedAccountId ?? 0);
  Future<List<String>> savedNames() => _db.getSavedNames();

  double get totalReceived => transfers.where((t) => t.type == TransferType.received).fold(0, (s, t) => s + t.amount);
  double get totalPaid => transfers.where((t) => t.type == TransferType.paid).fold(0, (s, t) => s + t.amount);
  double get totalCommission => transfers.where((t) => t.type == TransferType.paid).fold(0, (s, t) => s + t.commission);
  double get balance => (selectedAccount?.openingBalance ?? 0) + totalReceived - totalPaid - totalCommission;
  int get paidCount => transfers.where((t) => t.type == TransferType.paid).length;

  // Debts
  Future<void> loadDebts() async { debts = await _db.getDebts(); notifyListeners(); }
  int get unsettledDebtsCount => debts.where((d) => !d.isSettled).length;
  Future<void> addDebt(Debt d) async { await _db.insertDebt(d); await loadDebts(); }
  Future<void> updateDebt(Debt d) async { await _db.updateDebt(d); await loadDebts(); }
  Future<void> deleteDebt(int id) async { await _db.deleteDebt(id); await loadDebts(); }

  Future<void> restoreBackup(String jsonStr) async { await _db.restoreBackup(jsonStr); await loadAccounts(); await loadDebts(); }
  Future<void> clearAllData() async { await _db.clearAll(); accounts = []; transfers = []; debts = []; selectedAccountId = null; notifyListeners(); }
}
