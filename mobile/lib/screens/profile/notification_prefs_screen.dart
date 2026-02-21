import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

// Preference keys stored inside user_metadata['notification_prefs']
class _Pref {
  const _Pref({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
}

const _kPrefs = [
  _Pref(
    key: 'review_responses',
    title: 'Review responses',
    subtitle: 'When a business owner replies to your review',
    icon: Icons.reply_rounded,
  ),
  _Pref(
    key: 'new_near_me',
    title: 'New businesses nearby',
    subtitle: 'When a new listing opens in your area',
    icon: Icons.store_rounded,
  ),
  _Pref(
    key: 'promotions',
    title: 'Deals & promotions',
    subtitle: 'Special offers from businesses you\'ve saved',
    icon: Icons.local_offer_rounded,
  ),
  _Pref(
    key: 'weekly_digest',
    title: 'Weekly digest',
    subtitle: 'A summary of top-rated businesses near you',
    icon: Icons.summarize_rounded,
  ),
  _Pref(
    key: 'account_activity',
    title: 'Account activity',
    subtitle: 'Sign-ins and important account updates',
    icon: Icons.security_rounded,
  ),
];

class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  State<NotificationPrefsScreen> createState() =>
      _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends State<NotificationPrefsScreen> {
  // pref key → enabled
  Map<String, bool> _prefs = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Load from user metadata ────────────────────────────────────────────────

  void _load() {
    final meta = SupabaseClientProvider.currentUser?.userMetadata;
    final stored =
        meta?['notification_prefs'] as Map<String, dynamic>? ?? {};

    setState(() {
      _prefs = {
        for (final p in _kPrefs)
          // Default: account_activity always on, others on
          p.key: stored[p.key] as bool? ?? true,
      };
      _loading = false;
    });
  }

  // ── Persist to user metadata ───────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SupabaseClientProvider.auth.updateUser(
        UserAttributes(data: {'notification_prefs': _prefs}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, st) {
      dev.log('NotificationPrefs save error: $e', stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save preferences. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggle(String key, bool value) {
    setState(() => _prefs[key] = value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(128),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your device notification settings must also allow notifications from this app.',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withAlpha(179),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Preferences list
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: colorScheme.outline.withAlpha(38)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (int i = 0; i < _kPrefs.length; i++) ...[
                        _PrefTile(
                          pref: _kPrefs[i],
                          value: _prefs[_kPrefs[i].key] ?? true,
                          onChanged: (v) =>
                              _toggle(_kPrefs[i].key, v),
                        ),
                        if (i < _kPrefs.length - 1)
                          Divider(
                            height: 1,
                            indent: 60,
                            color: colorScheme.outline.withAlpha(38),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Pref tile ─────────────────────────────────────────────────────────────────

class _PrefTile extends StatelessWidget {
  const _PrefTile({
    required this.pref,
    required this.value,
    required this.onChanged,
  });
  final _Pref pref;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primary.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(pref.icon, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pref.title,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  pref.subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colorScheme.onSurface.withAlpha(115),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}