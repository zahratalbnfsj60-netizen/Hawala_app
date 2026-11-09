import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'home_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinCtrl = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<AppProvider>();
      if (p.bioEnabled) {
        final ok = await p.tryBiometric();
        if (ok && mounted) _unlock();
      }
    });
  }
  void _unlock() {
    context.read<AppProvider>().setUnlocked(true);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock, size: 64, color: Colors.white),
            const SizedBox(height: 24),
            if (p.hasPin) ...[
              TextField(controller: _pinCtrl, obscureText: true, keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 6, decoration: const InputDecoration(hintText: 'أدخل رمز الدخول'), onSubmitted: (v) { if (p.verifyPin(v)) _unlock(); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رمز خاطئ'))); }),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 50, child: FilledButton(onPressed: () { if (p.verifyPin(_pinCtrl.text)) _unlock(); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رمز خاطئ'))); }, child: const Text('دخول'))),
            ],
            if (p.bioEnabled) ...[
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(onPressed: () async { if (await p.tryBiometric()) _unlock(); }, icon: const Icon(Icons.fingerprint), label: const Text('بصمة'))),
            ],
          ]),
        ),
      ),
    );
  }
}
