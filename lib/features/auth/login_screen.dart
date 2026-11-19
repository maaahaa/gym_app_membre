import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../member/member_shell.dart';
import 'register_screen.dart';

String? validateEmail(String? v) {
  final value = (v ?? '').trim();
  if (value.isEmpty) return 'Adresse e-mail obligatoire';
  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  return ok ? null : "Format d'e-mail invalide";
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final AuthService _authService = AuthService();

  bool _hidden = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final credential = await _authService.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      final uid = credential.user?.uid;
      final profile = uid == null ? null : await UserRepository().getUser(uid);
      if (profile == null || profile.role != 'member' || !profile.isActive) {
        await _authService.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ce compte n’est pas un compte adhérent actif.',
            ),
          ),
        );
        return;
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MemberShell(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;
      switch (e.code) {
        case 'invalid-email':
          message = "L'adresse e-mail est invalide.";
          break;
        case 'user-not-found':
        case 'invalid-credential':
        case 'wrong-password':
          message = 'E-mail ou mot de passe incorrect.';
          break;
        case 'user-disabled':
          message = 'Ce compte a été désactivé.';
          break;
        case 'too-many-requests':
          message = 'Trop de tentatives. Réessaie plus tard.';
          break;
        case 'network-request-failed':
          message = 'Vérifie ta connexion Internet.';
          break;
        default:
          message = 'Connexion impossible (${e.code}). Réessaie.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Une erreur est survenue. Réessaie.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    final ctrl = TextEditingController();
    final key = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool sending = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (contextDialog, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                'Mot de passe oublié',
                style: AppText.title(22),
              ),
              content: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: ctrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Adresse e-mail',
                      ),
                      validator: validateEmail,
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      sending ? null : () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Annuler',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
                TextButton(
                  onPressed: sending
                      ? null
                      : () async {
                          if (!key.currentState!.validate()) return;

                          setDialogState(() {
                            sending = true;
                            errorMessage = null;
                          });

                          try {
                            await _authService.sendPasswordResetEmail(
                              email: ctrl.text.trim(),
                            );

                            if (!dialogContext.mounted) return;

                            Navigator.pop(dialogContext);

                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Si cette adresse correspond à un compte, '
                                  'un lien de réinitialisation sera envoyé.',
                                ),
                              ),
                            );
                          } catch (_) {
                            if (!dialogContext.mounted) return;

                            setDialogState(() {
                              sending = false;
                              errorMessage =
                                  'Une erreur est survenue. Réessaie.';
                            });
                          }
                        },
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Envoyer',
                          style: TextStyle(color: AppColors.lime),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                Text(
                  'ESPACE ADHÉRENT',
                  style: AppText.eyebrow(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connexion',
                  style: AppText.title(40),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connecte-toi pour accéder à tes séances.',
                  style: AppText.body(
                    13,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Adresse e-mail',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: validateEmail,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _hidden,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _hidden
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() => _hidden = !_hidden);
                      },
                    ),
                  ),
                  validator: (v) {
                    if ((v ?? '').isEmpty) {
                      return 'Mot de passe obligatoire';
                    }
                    if (v!.length < 6) {
                      return 'Minimum 6 caractères';
                    }
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: Text(
                      'Mot de passe oublié ?',
                      style: AppText.body(
                        12,
                        color: AppColors.lime,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  'Se connecter',
                  onPressed: _loading ? null : () => _submit(),
                ),
                if (_loading) ...[
                  const SizedBox(height: 12),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Pas de compte ? Créer un compte',
                      style: AppText.body(
                        12.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
