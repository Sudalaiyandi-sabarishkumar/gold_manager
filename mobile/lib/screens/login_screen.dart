import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/coin.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController(text: '');
  final _password = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await context.read<AppState>().login(_username.text, _password.text);
    } catch (_) {
      // Message is surfaced from AppState.error below.
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: GoldColors.muted),
      floatingLabelStyle:
          const TextStyle(color: GoldColors.gold, fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, color: GoldColors.muted, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: GoldColors.surface2,
      border: border(GoldColors.hairline),
      enabledBorder: border(GoldColors.hairline),
      focusedBorder: border(GoldColors.gold, 2),
      errorBorder: border(GoldColors.loss),
      focusedErrorBorder: border(GoldColors.loss, 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = context.select<AppState, String?>((s) => s.error);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.9),
            radius: 1.4,
            colors: [Color(0xFF3D2C10), GoldColors.bg],
            stops: [0, 0.75],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 148,
                    height: 148,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          GoldColors.gold.withValues(alpha: 0.32),
                          GoldColors.gold.withValues(alpha: 0),
                        ],
                      ),
                    ),
                    child: const Center(child: Coin(size: 100)),
                  ),
                  // const SizedBox(height: 12),
                  // ShaderMask(
                  //   shaderCallback: (bounds) => const LinearGradient(
                  //     colors: [
                  //       Color(0xFFFCE7A0),
                  //       GoldColors.gold,
                  //       GoldColors.goldDeep,
                  //     ],
                  //   ).createShader(bounds),
                  //   child: const Text(
                  //     'AVS',
                  //     style: TextStyle(
                  //       fontFamily: 'serif',
                  //       fontSize: 42,
                  //       fontWeight: FontWeight.w800,
                  //       color: Colors.white,
                  //       letterSpacing: 3,
                  //     ),
                  //   ),
                  // ),
                  // const SizedBox(height: 6),
                  const Text(
                    'Stock & ledger, refined',
                    style: TextStyle(
                      color: GoldColors.muted,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 34),
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [GoldColors.surface, GoldColors.surface2],
                      ),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: GoldColors.hairline),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 32,
                          offset: const Offset(0, 18),
                          spreadRadius: -6,
                        ),
                      ],
                    ),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Welcome back',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: GoldColors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Sign in to continue',
                            style: TextStyle(color: GoldColors.faint, fontSize: 13),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _username,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(color: GoldColors.text),
                            decoration: _decoration(
                              label: 'Username',
                              icon: Icons.person_outline,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter a username'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(color: GoldColors.text),
                            decoration: _decoration(
                              label: 'Password',
                              icon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                tooltip:
                                    _obscure ? 'Show password' : 'Hide password',
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: GoldColors.muted,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            onFieldSubmitted: (_) => _submit(),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Enter a password'
                                : null,
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              error,
                              style: const TextStyle(
                                  color: GoldColors.loss, fontSize: 13),
                            ),
                          ],
                          const SizedBox(height: 26),
                          Container(
                            height: 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: const LinearGradient(
                                colors: [
                                  Color.fromARGB(255, 223, 198, 116),
                                  GoldColors.gold,
                                  GoldColors.goldDeep,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: GoldColors.gold.withValues(alpha: 0.35),
                                  blurRadius: 22,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: _submitting ? null : _submit,
                                child: Center(
                                  child: _submitting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: GoldColors.goldInk,
                                          ),
                                        )
                                      : const Text(
                                          'Sign in',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: GoldColors.goldInk,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Session stays active until you log out.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: GoldColors.faint, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
