import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/animated_finance_preview.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          if (wide) {
            return Row(
              children: [
                Expanded(flex: 6, child: _HeroPanel()),
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
          // Mobile: compact hero header stacked above the form.
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const SizedBox(height: 190, child: AnimatedFinancePreview())
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 28),
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            "Hami's been keeping an eye on things.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (value) => (value == null || !value.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_isLoading) _handleLogin();
            },
            decoration: const InputDecoration(labelText: 'Password'),
            validator: (value) =>
                (value == null || value.length < 8) ? 'Password must be at least 8 characters' : null,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: AppColors.expense)),
          ],
          const SizedBox(height: 24),
          PrimaryButton(label: 'Log in', onPressed: _handleLogin, isLoading: _isLoading),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => context.go('/register'),
              child: const Text("Don't have an account? Sign up"),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
    );
  }
}

/// Dark premium hero (wide screens): brand, headline, the live finance
/// preview, and a status footer — echoing a fintech sign-in split layout.
class _HeroPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141824), Color(0xFF0B0D14)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Text('₱', style: TextStyle(color: Color(0xFF241A05), fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 10),
                const Text('Hamili',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
            const Spacer(),
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, height: 1.1, color: Colors.white),
                children: [
                  TextSpan(text: 'Precision tracking\nfor '),
                  TextSpan(text: 'every peso.', style: TextStyle(color: AppColors.primary)),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.08, end: 0, curve: Curves.easeOutCubic),
            const SizedBox(height: 14),
            Text(
              'Budgets, goals, and proactive AI insights from Hami — your money, finally in focus.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 15, height: 1.5),
            ).animate(delay: 120.ms).fadeIn(duration: 500.ms),
            const SizedBox(height: 28),
            Expanded(
              child: const AnimatedFinancePreview()
                  .animate(delay: 200.ms)
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: AppColors.income, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text('SYSTEMS NOMINAL',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, letterSpacing: 2)),
                const Spacer(),
                Text('VERSION 1.0.0',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, letterSpacing: 2)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
