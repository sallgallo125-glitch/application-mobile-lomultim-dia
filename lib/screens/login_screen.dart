import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_providers.dart';
import '../theme/tokens.dart';
import '../widgets/app_header.dart' show AppBackButton;

/// Sign-in: logo, "Connexion", e-mail or phone + password, link to sign-up.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    final account = findAccount(
        ref.read(registeredAccountsProvider), _identifier.text, _password.text);
    if (account == null) {
      setState(() => _error = 'E-mail, téléphone ou mot de passe incorrect.');
      return;
    }
    ref.read(sessionUserProvider.notifier).state =
        SessionUser(name: account.fullName, phone: account.phone);
    context.go('/compte');
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: 'Connexion',
        child: Form(
          key: _form,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AuthField(
              controller: _identifier,
              label: 'Email ou téléphone',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Indiquez votre e-mail ou votre téléphone.'
                  : null,
            ),
            AuthField(
              controller: _password,
              label: 'Mot de passe',
              icon: Icons.lock_outline,
              password: true,
              last: true,
              onSubmitted: _submit,
              validator: (v) =>
                  (v ?? '').isEmpty ? 'Indiquez votre mot de passe.' : null,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.danger, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: AppSpacing.sm),
            AuthButton(label: 'Se connecter', onPressed: _submit),
            const SizedBox(height: AppSpacing.lg),
            AuthLink(
                text: 'Pas encore de compte ? ',
                action: "S'inscrire",
                onTap: () => context.pushReplacement('/inscription')),
          ]),
        ),
      );
}

/// Sign-up: first/last name, e-mail, phone, address, password + confirmation.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _firstName,
      _lastName,
      _email,
      _phone,
      _address,
      _password,
      _confirm
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v, String what) =>
      (v ?? '').trim().length < 2 ? 'Indiquez votre $what.' : null;

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final account = RegisteredAccount(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        password: _password.text);
    final accounts = ref.read(registeredAccountsProvider);
    final taken = [demoAccount, ...accounts].any((a) =>
        a.email.toLowerCase() == account.email.toLowerCase() ||
        a.phoneDigits == account.phoneDigits);
    if (taken) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Un compte existe déjà avec cet e-mail ou ce téléphone.')));
      return;
    }
    ref.read(registeredAccountsProvider.notifier).state = [
      ...accounts,
      account
    ];
    ref.read(sessionUserProvider.notifier).state =
        SessionUser(name: account.fullName, phone: account.phone);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Bienvenue ${account.firstName} ! Votre compte est créé.')));
    context.go('/compte');
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: 'Inscription',
        child: Form(
          key: _form,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AuthField(
                controller: _firstName,
                label: 'Prénom',
                icon: Icons.person_outline,
                capitalize: true,
                validator: (v) => _required(v, 'prénom')),
            AuthField(
                controller: _lastName,
                label: 'Nom',
                icon: Icons.badge_outlined,
                capitalize: true,
                validator: (v) => _required(v, 'nom')),
            AuthField(
                controller: _email,
                label: 'Email',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch((v ?? '').trim())
                    ? null
                    : 'Adresse e-mail invalide.'),
            AuthField(
                controller: _phone,
                label: 'Téléphone',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    (v ?? '').replaceAll(RegExp(r'\D'), '').length < 9
                        ? 'Numéro de téléphone incomplet.'
                        : null),
            AuthField(
                controller: _address,
                label: 'Adresse',
                icon: Icons.location_on_outlined,
                keyboardType: TextInputType.streetAddress,
                validator: (v) => _required(v, 'adresse')),
            AuthField(
                controller: _password,
                label: 'Mot de passe',
                icon: Icons.lock_outline,
                password: true,
                validator: (v) =>
                    (v ?? '').length < 6 ? 'Au moins 6 caractères.' : null),
            AuthField(
                controller: _confirm,
                label: 'Confirmer le mot de passe',
                icon: Icons.lock_outline,
                password: true,
                last: true,
                onSubmitted: _submit,
                validator: (v) => v != _password.text
                    ? 'Les mots de passe ne correspondent pas.'
                    : null),
            const SizedBox(height: AppSpacing.sm),
            AuthButton(label: "S'inscrire", onPressed: _submit),
            const SizedBox(height: AppSpacing.lg),
            AuthLink(
                text: 'Déjà un compte ? ',
                action: 'Se connecter',
                onTap: () => context.pushReplacement('/connexion')),
          ]),
        ),
      );
}

/// White page with a back arrow, the centred logo and a big title.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.lg),
                child: AppBackButton(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/compte'),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Image.asset('assets/images/logo.png',
                                height: 84, semanticLabel: 'LO Multimédia'),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(title,
                              textAlign: TextAlign.center,
                              style: AppText.pageTitle),
                          const SizedBox(height: AppSpacing.xl),
                          child,
                        ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
}

/// Rounded field with a leading icon; [password] adds the show/hide eye.
class AuthField extends StatefulWidget {
  const AuthField(
      {super.key,
      required this.controller,
      required this.label,
      required this.icon,
      this.validator,
      this.keyboardType,
      this.password = false,
      this.capitalize = false,
      this.last = false,
      this.onSubmitted});
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final bool password;
  final bool capitalize;
  final bool last;
  final VoidCallback? onSubmitted;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _hidden = true;

  OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width));

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          obscureText: widget.password && _hidden,
          autocorrect: !widget.password,
          textCapitalization: widget.capitalize
              ? TextCapitalization.words
              : TextCapitalization.none,
          textInputAction:
              widget.last ? TextInputAction.done : TextInputAction.next,
          onFieldSubmitted: (_) => widget.onSubmitted?.call(),
          style: const TextStyle(fontSize: 16, color: AppColors.text),
          decoration: InputDecoration(
            hintText: widget.label,
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            prefixIcon: Icon(widget.icon, color: AppColors.text),
            suffixIcon: widget.password
                ? IconButton(
                    tooltip: _hidden
                        ? 'Afficher le mot de passe'
                        : 'Masquer le mot de passe',
                    icon: Icon(
                        _hidden
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textSecondary),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : null,
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            enabledBorder: _border(AppColors.border),
            focusedBorder: _border(AppColors.primary, 1.6),
            errorBorder: _border(AppColors.danger),
            focusedErrorBorder: _border(AppColors.danger, 1.6),
          ),
        ),
      );
}

class AuthButton extends StatelessWidget {
  const AuthButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle:
                const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      );
}

class AuthLink extends StatelessWidget {
  const AuthLink(
      {super.key,
      required this.text,
      required this.action,
      required this.onTap});
  final String text;
  final String action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Center(
        child: TextButton(
          onPressed: onTap,
          child: Text.rich(TextSpan(
              style: const TextStyle(fontSize: 15, color: AppColors.primary),
              children: [
                TextSpan(text: text),
                TextSpan(
                    text: action,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ])),
        ),
      );
}
