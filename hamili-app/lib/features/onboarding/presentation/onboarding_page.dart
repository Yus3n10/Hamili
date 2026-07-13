import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../auth/presentation/auth_providers.dart';


class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pageController = PageController();
  final _goalController = TextEditingController();
  int _index = 0;
  String _currency = 'PHP';
  bool _saving = false;

  static const _currencies = ['PHP', 'USD', 'EUR', 'GBP', 'JPY'];

  @override
  void dispose() {
    _pageController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  void _next() {
    _pageController.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await ref.read(currentUserProvider.notifier).updateProfile(
            preferredCurrency: _currency,
            financialGoalText: _goalController.text.trim().isEmpty ? null : _goalController.text.trim(),
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save preferences — you can set them later in Profile.")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _index = i),
                children: [_welcomePage(context), _preferencesPage(context)],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 2; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _index == i ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _index == i ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _welcomePage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('Hi, I’m Hami!', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            'I’ll help you track spending, set budgets and goals, and spot patterns — '
            'and I’ll nudge you with proactive insights along the way.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          PrimaryButton(label: 'Get started', onPressed: _next),
        ],
      ),
    );
  }

  Widget _preferencesPage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView(
        children: [
          const SizedBox(height: 24),
          Text('A couple of preferences', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('You can change these anytime in Profile.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(labelText: 'Preferred currency'),
            items: [for (final c in _currencies) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => _currency = v ?? 'PHP'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _goalController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'What are you saving for? (optional)',
              hintText: 'e.g. Emergency fund, new laptop, a trip',
            ),
          ),
          const SizedBox(height: 32),
          PrimaryButton(label: 'Finish', onPressed: _finish, isLoading: _saving),
        ],
      ),
    );
  }
}
