import 'package:flutter/material.dart';
import '../constants.dart';
import 'context_select_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  String? _error;
  static const _demoId = 'hardy';
  static const _demoPw = '1234';

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  void _login() {
    final id = _idCtrl.text.trim();
    final pw = _pwCtrl.text;
    if (id == _demoId && pw == _demoPw) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ContextSelectScreen()),
      );
    } else {
      setState(() => _error = '아이디 또는 비밀번호가 올바르지 않습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: hammerYellow,
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Image.asset('assets/hammer_industry.png', width: 900, fit: BoxFit.contain),
            ),
          ),
          Positioned.fill(child: Container(color: hammerYellow.withOpacity(0.85))),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 10,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('HAMMER', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextField(controller: _idCtrl, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'ID', border: OutlineInputBorder())),
                        const SizedBox(height: 12),
                        TextField(controller: _pwCtrl, obscureText: true, onSubmitted: (_) => _login(), decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
                        const SizedBox(height: 12),
                        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                        ElevatedButton(onPressed: _login, child: const Text('Sign in')),
                        const SizedBox(height: 8),
                        const Text('Demo: id=hardy / pw=1234', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
