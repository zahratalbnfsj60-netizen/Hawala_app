import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'main_screen.dart';
import 'lock_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() { super.initState(); _go(); }
  Future<void> _go() async { await Future.delayed(const Duration(milliseconds: 600)); if (!mounted) return; final p = context.read<AppProvider>(); final target = p.needsUnlock ? const LockScreen() : const MainScreen(); Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => target)); }
  @override
  Widget build(BuildContext context) { return const Scaffold(backgroundColor: Colors.black, body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.account_balance_wallet, size: 80, color: Color(0xFF00C853)), SizedBox(height: 16), Text('سجل الحوالات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))]))); }
}
