import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/models.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../member/member_shell.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  final AuthService _authService = AuthService();
  final UserRepository _userRepository = UserRepository();

  bool _hidden = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final credential = await _authService.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Utilisateur non créé');
      }

      final appUser = AppUser(
        id: user.uid,
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        role: 'member',
        createdAt: DateTime.now(),
      );

      await _userRepository.createUser(appUser);

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MemberShell(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'Cette adresse e-mail est déjà utilisée.';
          break;
        case 'weak-password':
          message = 'Le mot de passe est trop faible.';
          break;
        case 'invalid-email':
          message = "L'adresse e-mail est invalide.";
          break;
        default:
          message = 'Erreur lors de l’inscription (${e.code}).';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Form(
            key: _key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REJOINS-NOUS',
                  style: AppText.eyebrow(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Créer un compte',
                  style: AppText.title(36),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().length < 3 ? 'Nom trop court' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Adresse e-mail',
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) {
                      return 'Adresse e-mail obligatoire';
                    }
                    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)
                        ? null
                        : "Format d'e-mail invalide";
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone (8 chiffres)',
                  ),
                  validator: (v) => RegExp(r'^\d{8}$').hasMatch((v ?? '').trim())
                      ? null
                      : 'Numéro à 8 chiffres',
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _password,
                  obscureText: _hidden,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
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
                  validator: (v) =>
                      (v ?? '').length < 6 ? 'Minimum 6 caractères' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _confirm,
                  obscureText: _hidden,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le mot de passe',
                  ),
                  validator: (v) =>
                      v != _password.text ? 'Les mots de passe diffèrent' : null,
                ),
                const SizedBox(height: 24),

                PrimaryButton(
                  _loading ? 'Création du compte...' : "S'inscrire",
                  onPressed: _loading ? null : _submit,
                ),

                if (_loading) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],

                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                    child: Text(
                      'Déjà un compte ? Se connecter',
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
