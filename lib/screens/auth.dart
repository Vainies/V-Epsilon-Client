import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../theme.dart';

class AuthScreen extends StatefulWidget {
  final bool firstRun;
  const AuthScreen({super.key, this.firstRun = false});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _handle = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  bool _isGB = false;
  bool _gbAccepted = false;

  @override
  void initState() {
    super.initState();
    _checkGeo();
  }

  Future<void> _checkGeo() async {
    try {
      final res = await http.get(Uri.parse('http://ip-api.com/json/')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['countryCode'] == 'GB') {
          if (mounted) setState(() => _isGB = true);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _handle.dispose(); _name.dispose(); _email.dispose(); _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_register && _isGB && !_gbAccepted) {
      setState(() => _error = 'GB users must accept the privacy liability terms');
      return;
    }
    final api = context.read<Api>();
    setState(() { _busy = true; _error = null; });
    try {
      if (_register) {
        await api.register(_handle.text.trim(), _name.text.trim(), _password.text,
            email: _email.text.trim().isEmpty ? null : _email.text.trim());
      } else {
        await api.login(_handle.text.trim(), _password.text);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VE.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const Text('ε', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: VE.blue, height: 1)),
                  const SizedBox(height: 4),
                  Text(_register ? 'Create account' : 'Sign in',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: VE.text, fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 24),
                  _f('handle', _handle, Icons.alternate_email_rounded),
                  if (_register) ...[
                    const SizedBox(height: 8),
                    _f('display name', _name, Icons.person_outline_rounded),
                    const SizedBox(height: 8),
                    _f('email (optional)', _email, Icons.email_outlined, keyboard: TextInputType.emailAddress),
                  ],
                  const SizedBox(height: 8),
                  _f('password', _password, Icons.lock_outline_rounded, obscure: true),
                  if (_register && _isGB) ...[
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _gbAccepted, onChanged: (v) => setState(() => _gbAccepted = v ?? false),
                      title: const Text('I acknowledge the privacy liability terms.',
                          style: TextStyle(color: VE.textDim, fontSize: 11, height: 1.3)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero, activeColor: VE.blue, checkColor: Colors.white, dense: true,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: VE.pink, fontSize: 11), textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: VE.text, foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5),
                      ),
                      child: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : Text(_register ? 'CREATE' : 'SIGN IN'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(_register ? 'Have an account?' : "Don't have an account?",
                        style: const TextStyle(color: VE.textMuted, fontSize: 12)),
                    TextButton(
                      onPressed: () => setState(() { _register = !_register; _error = null; }),
                      child: Text(_register ? 'Sign in' : 'Create',
                          style: const TextStyle(color: VE.blue, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _showPrivacyPolicy,
                    child: const Text('Privacy Policy',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: VE.textMuted, fontSize: 10, decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _f(String hint, TextEditingController c, IconData icon, {bool obscure = false, TextInputType? keyboard}) {
    return Container(
      decoration: BoxDecoration(
        color: VE.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VE.border),
      ),
      child: TextField(
        controller: c, obscureText: obscure, keyboardType: keyboard,
        style: const TextStyle(color: VE.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: VE.textMuted, fontSize: 14),
          prefixIcon: Icon(icon, size: 16, color: VE.textMuted),
          border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          isDense: true,
        ),
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => Dialog(
        backgroundColor: VE.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: VE.border)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: VE.text)),
            const SizedBox(height: 12),
            const Text(
              'Epsilon collects the minimum data needed to operate.\n'
              '• Handle, display name, avatar\n'
              '• Posts, comments, likes, follows\n'
              '• IP addresses for abuse prevention\n'
              '• Optional recovery email\n\n'
              'Your data stays yours. We do not sell or share it.\n'
              'You can export or delete everything at any time.',
              style: TextStyle(color: VE.textDim, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w800, color: VE.blue)),
            ),
          ]),
        ),
      ),
    );
  }
}
