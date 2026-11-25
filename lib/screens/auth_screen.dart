import 'package:flutter/material.dart';

import '../main.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'splash_screen.dart';

/// Sign in / create account. Accounts are stored on the phone for now;
/// "Continue with Google" is shown as a planned update.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _state = AppState.instance;
  late bool _signUp = _state.profile == null;
  final _name = TextEditingController();
  final _college = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email.text = _state.profile?.email ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _college.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = _signUp
        ? await _state.signUp(_name.text, _email.text, _password.text, college: _college.text)
        : await _state.signIn(_email.text, _password.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(fadeRoute(Shell()), (_) => false);
  }

  void _googleSoon() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Google sign-in and sync with Google Calendar and Classroom are coming in a future update.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Center(child: ClutchLogo(width: 110)),
            const SizedBox(height: 16),
            Center(child: ClutchWordmark(size: 26)),
            const SizedBox(height: 28),
            Text(_signUp ? 'Create your account' : 'Welcome back', style: heading(26)),
            const SizedBox(height: 6),
            Text(
              _signUp
                  ? 'Set up CLUTCH so it knows who it is planning for.'
                  : 'Sign in to pick up where you left off.',
              style: TextStyle(color: C.muted),
            ),
            const SizedBox(height: 24),
            if (_signUp) ...[
              _field(_name, 'Full name', Icons.person_outline, TextInputType.name),
              const SizedBox(height: 12),
              _field(_college, 'College (optional)', Icons.school_outlined, TextInputType.text),
              const SizedBox(height: 12),
            ],
            _field(_email, 'Email', Icons.mail_outline, TextInputType.emailAddress),
            const SizedBox(height: 12),
            _field(_password, 'Password', Icons.lock_outline, TextInputType.visiblePassword,
                obscure: true),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: C.red)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: C.accent,
                  foregroundColor: C.onAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: C.onAccent))
                    : Text(_signUp ? 'Create account' : 'Sign in',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: Divider(color: C.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or', style: TextStyle(color: C.muted)),
              ),
              Expanded(child: Divider(color: C.border)),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: C.border),
                  foregroundColor: C.muted,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _googleSoon,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('G',
                      style: heading(20, color: C.muted, weight: FontWeight.w800)),
                  const SizedBox(width: 12),
                  Text('Continue with Google', style: TextStyle(color: C.muted, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  Pill('Soon', C.accent),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _signUp = !_signUp;
                  _error = null;
                }),
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: _signUp ? 'Already have an account? ' : 'New here? ',
                      style: TextStyle(color: C.muted)),
                  TextSpan(
                      text: _signUp ? 'Sign in' : 'Create an account',
                      style: TextStyle(color: C.accent, fontWeight: FontWeight.w700)),
                ])),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your account is stored on this phone. Google sign-in and syncing with Google tools arrive in a future update.',
              textAlign: TextAlign.center,
              style: TextStyle(color: C.muted, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, TextInputType type,
      {bool obscure = false}) {
    return TextField(
      controller: c,
      keyboardType: type,
      obscureText: obscure && _hide,
      style: TextStyle(color: C.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: C.muted),
        prefixIcon: Icon(icon, color: C.muted),
        suffixIcon: obscure
            ? IconButton(
                icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: C.muted),
                onPressed: () => setState(() => _hide = !_hide),
              )
            : null,
        filled: true,
        fillColor: C.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.border)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.border)),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.accent, width: 1.5)),
      ),
    );
  }
}
