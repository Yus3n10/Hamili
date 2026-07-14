import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/accent_palette.dart';
import '../../../core/theme/accent_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../dashboard/presentation/insights_enabled_provider.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/presentation/auth_providers.dart';
import 'avatar_edit.dart';
import 'avatar_providers.dart';
import 'edit_profile_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll need to sign in again to access your data."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(currentUserProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: userAsync.when(
        data: (user) => user == null
            ? const Center(child: Text('Not logged in'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: Stack(
                      children: [
                        UserAvatar(base64: ref.watch(avatarProvider), fallbackInitial: user.preferredName, radius: 48),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Material(
                            color: Theme.of(context).colorScheme.primary,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => pickAndSetAvatar(context, ref),
                              child: Padding(
                                padding: const EdgeInsets.all(7),
                                child: Icon(Icons.camera_alt, size: 16, color: Theme.of(context).colorScheme.onPrimary),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (ref.watch(avatarProvider) != null)
                    Center(
                      child: TextButton(
                        onPressed: () => ref.read(avatarProvider.notifier).clear(),
                        child: const Text('Remove photo'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  ListTile(title: const Text('Preferred name'), subtitle: Text(user.preferredName)),
                  ListTile(title: const Text('Email'), subtitle: Text(user.email)),
                  ListTile(title: const Text('Currency'), subtitle: Text(user.preferredCurrency)),
                  ListTile(
                    title: const Text('Financial goal'),
                    subtitle: Text(user.financialGoalText ?? 'Not set yet'),
                  ),
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 10),
                    child: Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_outlined),
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined),
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {ref.watch(themeModeProvider)},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) =>
                          ref.read(themeModeProvider.notifier).setThemeMode(selection.first),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 12),
                    child: Text('Accent color', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (final a in appAccents)
                          GestureDetector(
                            onTap: () => ref.read(accentProvider.notifier).setAccent(a),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: a.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ref.watch(accentProvider).name == a.name
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: ref.watch(accentProvider).name == a.name
                                  ? const Icon(Icons.check, color: Colors.white, size: 22)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Text('AI', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: const Text('AI insights from Hami'),
                    subtitle: const Text('Proactive nudges on your dashboard'),
                    value: ref.watch(insightsEnabledProvider),
                    onChanged: (v) => ref.read(insightsEnabledProvider.notifier).setEnabled(v),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => EditProfilePage(user: user)),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit profile'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _confirmLogout(context, ref),
                    child: const Text('Log out'),
                  ),
                ],
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Something went wrong')),
      ),
    );
  }
}
