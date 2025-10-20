// lib/components/login_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:poliedro_flutter/components/inputs/index.dart'; // seu Input custom
import 'package:poliedro_flutter/services/auth_service.dart';

class LoginCard extends StatefulWidget {
  const LoginCard({super.key});

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  final _formKey = GlobalKey<FormState>();
  final _emailOrRaCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _auth = AuthService();

  bool _obscure = true;
  bool _isLoading = false;
  bool _creatingAccount = false; // alterna Login/Cadastro

  @override
  void dispose() {
    _emailOrRaCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    String loginInput = _emailOrRaCtrl.text.trim();
    final pass = _passCtrl.text;

    try {
      // Se usuário digitou RA (sem "@"), buscar e-mail correspondente
      if (!loginInput.contains('@')) {
        final email = await _auth.buscarEmailPorRA(loginInput);
        if (email == null) {
          throw Exception('RA não encontrado. Verifique seus dados.');
        }
        loginInput = email;
      }

      if (_creatingAccount) {
        // Cadastro padrão como aluno (o AuthService já grava role='aluno')
        await _auth.signUpWithEmailAndPassword(loginInput, pass);
      } else {
        await _auth.signInWithEmailAndPassword(loginInput, pass);
      }

      if (!mounted) return;
      // Delega a decisão de dashboard para o IndexPage (que consulta role no Firestore)
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    FocusScope.of(context).unfocus();
    final input = _emailOrRaCtrl.text.trim();

    try {
      if (input.isEmpty) {
        throw Exception('Digite seu e-mail ou RA para recuperar a senha.');
      }

      String email = input;
      if (!input.contains('@')) {
        final found = await _auth.buscarEmailPorRA(input);
        if (found == null) {
          throw Exception('RA não encontrado. Digite um e-mail válido.');
        }
        email = found;
      }

      await _auth.resetPassword(email);
      if (!mounted) return;
      _showSnack('Enviamos um link de redefinição para $email');
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _creatingAccount ? 'Criar conta' : 'Login';
    final actionText = _creatingAccount ? 'Criar conta' : 'Entrar';

    return Card(
      elevation: 10,
      shadowColor: Colors.black.withOpacity(.12),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Título
              Row(
                children: [
                  Icon(
                    _creatingAccount ? Icons.person_add_alt_1 : Icons.lock_outline,
                    color: const Color(0xFF00BFFF),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // RA/E-mail
              Input(
                controller: _emailOrRaCtrl,
                placeholder: 'Digite seu RA ou e-mail',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.person_outline),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Informe seu RA ou e-mail';
                  // se for email, valida formato simples
                  if (value.contains('@') && !value.contains('.')) {
                    return 'E-mail inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Senha
              Input(
                controller: _passCtrl,
                placeholder: 'Digite sua senha',
                obscureText: _obscure,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: _isLoading
                      ? null
                      : () => setState(() => _obscure = !_obscure),
                ),
                validator: (v) {
                  final value = v ?? '';
                  if (value.isEmpty) return 'Informe sua senha';
                  if (value.length < 6) return 'Mínimo de 6 caracteres';
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Botão principal
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.login, color: Colors.white),
                  label: Text(
                    _isLoading ? 'Aguarde...' : actionText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFFF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Ações secundárias
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : _forgotPassword,
                    child: const Text(
                      'Esqueci minha senha',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() => _creatingAccount = !_creatingAccount),
                    child: Text(
                      _creatingAccount ? 'Já tenho conta' : 'Criar nova conta',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
