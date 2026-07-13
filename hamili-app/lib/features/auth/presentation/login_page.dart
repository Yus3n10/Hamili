import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/hamili_logo.dart';
import '../../../shared/widgets/primary_button.dart';
import 'auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(currentUserProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) context.go('/dashboard');
    } catch (_) {
      setState(() => _errorMessage = "Couldn't log in. Check your email and password.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          if (wide) {
            return Row(
              children: [
                const Expanded(flex: 6, child: _HeroPanel()),
                Expanded(
                  flex: 5,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: _buildForm(context),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          // Mobile: compact brand header stacked above the form.
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 36),
                  const AnimatedHamiliLogo(size: 84),
                  const SizedBox(height: 14),
                  Text('hamili',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Handle money. Achieve life.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 32),
                  _buildForm(context),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Welcome back.', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text('Handle money. Achieve life.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted)),
          const SizedBox(height: 28),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email', hintText: 'you@email.com'),
            validator: (value) => (value == null || !value.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_isLoading) _handleLogin();
            },
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                tooltip: _obscure ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (value) =>
                (value == null || value.length < 8) ? 'Password must be at least 8 characters' : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _forgotPassword, child: const Text('Forgot password?')),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(_errorMessage!, style: const TextStyle(color: AppColors.expense)),
          ],
          const SizedBox(height: 16),
          PrimaryButton(label: 'Sign in', onPressed: _handleLogin, isLoading: _isLoading),
          const SizedBox(height: 16),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('New to Hamili? ', style: TextStyle(color: muted)),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('Create an account'),
                ),
              ],
            ),
          ),
        ],
      ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
    );
  }
}

/// Brand hero (wide screens): the animated Hamili mark, wordmark, welcome
/// line, and tagline on a green→navy gradient panel.
class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16A34A), Color(0xFF0F172A)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                HamiliLogo(size: 40),
                SizedBox(width: 12),
                Text('hamili',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              ],
            ),
            const Spacer(),
            const Center(child: AnimatedHamiliLogo(size: 132)),
            const SizedBox(height: 40),
            const Text('Welcome back.',
                    style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, height: 1.1, color: Colors.white))
                .animate()
                .fadeIn(duration: 500.ms)
                .slideX(begin: -0.08, end: 0, curve: Curves.easeOutCubic),
            const SizedBox(height: 14),
            Text(
              'Handle money. Achieve life. Budgets, goals, and proactive insights from Hami — your money, finally in focus.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 15, height: 1.5),
            ).animate(delay: 120.ms).fadeIn(duration: 500.ms),
            const Spacer(),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text('Trust · Growth · Simplicity',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, letterSpacing: 1.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
