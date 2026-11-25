import 'voice_picker_screen.dart';
import 'plans_screen.dart';
import 'package:flutter/material.dart';

import '../models/settings.dart';
import '../services/clutch_agent.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'auth_screen.dart';
import 'chat_history_screen.dart';
import 'splash_screen.dart';
import 'tutorial_screen.dart';

void openSettings(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: C.surface,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => _SettingsSheet(scroll: scroll, rootContext: context),
    ),
  );
}

const _personalityText = {
  Personality.witty: ('Witty coach', 'Sharp, a little funny, always on your side'),
  Personality.calm: ('Calm mentor', 'Gentle, steady, no pressure in the tone'),
  Personality.strict: ('Strict trainer', 'Blunt and no-nonsense, zero excuses'),
};

class _SettingsSheet extends StatelessWidget {
  final ScrollController scroll;
  final BuildContext rootContext;
  const _SettingsSheet({required this.scroll, required this.rootContext});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final s = state.settings;
        final p = state.profile;
        return Material(
          color: C.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text('Settings', style: heading(24)),
              const SizedBox(height: 16),

              // ---------- profile ----------
              if (p != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: C.surface2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: C.border),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: C.accent,
                      child: Text(p.initials,
                          style: TextStyle(color: C.onAccent, fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(p.email, style: TextStyle(color: C.muted, fontSize: 13)),
                        if (p.college.isNotEmpty)
                          Text(p.college, style: TextStyle(color: C.muted, fontSize: 13)),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Edit profile',
                      icon: Icon(Icons.edit_outlined, color: C.muted),
                      onPressed: () => _editProfile(context),
                    ),
                  ]),
                ),
              const SizedBox(height: 12),
              Panel(
                onTap: () {
                  final nav = Navigator.of(rootContext, rootNavigator: true);
                  Navigator.pop(context);
                  nav.push(MaterialPageRoute(builder: (_) => const PlansScreen()));
                },
                borderColor: s.ultra ? C.accent : null,
                child: Row(children: [
                  if (s.ultra) const UltraBadge() else Text('Free plan', style: heading(16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s.ultra ? 'Claude brain, AI steps, your voice' : 'Ultra Pro · coming in the next update',
                        style: TextStyle(color: C.muted, fontSize: 13)),
                  ),
                  Icon(Icons.chevron_right, color: C.muted),
                ]),
              ),
              const SizedBox(height: 24),

              // ---------- appearance ----------
              _section('APPEARANCE'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: C.accent,
                secondary: Icon(s.darkMode ? Icons.dark_mode : Icons.light_mode, color: C.accent),
                title: Text('Dark mode', style: TextStyle(color: C.text)),
                value: s.darkMode,
                onChanged: (v) => state.updateSettings((x) => x.darkMode = v),
              ),
              const SizedBox(height: 4),
              Text('Accent colour', style: TextStyle(color: C.text)),
              const SizedBox(height: 10),
              Wrap(spacing: 12, runSpacing: 12, children: [
                for (var i = 0; i < C.accents.length; i++)
                  GestureDetector(
                    onTap: () => state.updateSettings((x) => x.accentIndex = i),
                    child: Tooltip(
                      message: C.accents[i].name,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: C.accents[i].color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: s.accentIndex == i ? C.text : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: s.accentIndex == i ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 24),

              // ---------- personality ----------
              _section('CLUTCH PERSONALITY'),
              for (final entry in _personalityText.entries)
                RadioListTile<Personality>(
                  contentPadding: EdgeInsets.zero,
                  activeColor: C.accent,
                  value: entry.key,
                  groupValue: s.personality,
                  onChanged: (v) {
                    if (v == null) return;
                    state.updateSettings((x) => x.personality = v);
                    ClutchAgent.instance.resetConversation();
                  },
                  title: Text(entry.value.$1, style: TextStyle(color: C.text)),
                  subtitle: Text(entry.value.$2, style: TextStyle(color: C.muted, fontSize: 12)),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.graphic_eq, color: s.ultra ? C.accent : C.muted),
                title: Text('CLUTCH voice', style: TextStyle(color: C.text)),
                subtitle: Text(
                    s.ultra ? (s.voiceName ?? 'Default ElevenLabs voice') : 'Phone voice · custom voices coming soon',
                    style: TextStyle(color: C.muted, fontSize: 12)),
                trailing: s.ultra ? Icon(Icons.chevron_right, color: C.muted) : Pill('Soon', C.accent),
                onTap: () {
                  final nav = Navigator.of(rootContext, rootNavigator: true);
                  Navigator.pop(context);
                  nav.push(MaterialPageRoute(
                      builder: (_) => s.ultra ? const VoicePickerScreen() : const PlansScreen()));
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: C.accent,
                title: Text('Speak replies out loud', style: TextStyle(color: C.text)),
                subtitle: Text(s.ultra ? 'In your chosen voice' : 'Using the phone voice',
                    style: TextStyle(color: C.muted, fontSize: 12)),
                value: s.voiceReplies,
                onChanged: (v) => state.updateSettings((x) => x.voiceReplies = v),
              ),
              const SizedBox(height: 16),

              // ---------- planning ----------
              _section('PLANNING'),
              Text('Free study window: ${s.workStartHour}:00 – ${s.workEndHour}:00',
                  style: TextStyle(color: C.text)),
              RangeSlider(
                values: RangeValues(s.workStartHour.toDouble(), s.workEndHour.toDouble()),
                min: 0,
                max: 24,
                divisions: 24,
                activeColor: C.accent,
                onChanged: (v) {
                  if (v.end - v.start < 1) return;
                  state.updateSettings((x) {
                    x.workStartHour = v.start.round();
                    x.workEndHour = v.end.round();
                  });
                },
              ),
              Text('Focus hours per day: ${s.dailyCapacity.toStringAsFixed(1)} h', style: TextStyle(color: C.text)),
              Slider(
                value: s.dailyCapacity,
                min: 1,
                max: 12,
                divisions: 22,
                activeColor: C.accent,
                onChanged: (v) => state.updateSettings((x) => x.dailyCapacity = v),
              ),
              const SizedBox(height: 8),

              // ---------- help ----------
              _section('HELP'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.school_outlined, color: C.accent),
                title: Text('Take the tutorial', style: TextStyle(color: C.text)),
                subtitle: Text('A guided tour on a demo week. Your own tasks are kept safe.',
                    style: TextStyle(color: C.muted, fontSize: 12)),
                trailing: Icon(Icons.chevron_right, color: C.muted),
                onTap: () {
                  final nav = Navigator.of(rootContext, rootNavigator: true);
                  Navigator.pop(context);
                  nav.push(MaterialPageRoute(builder: (_) => const TutorialScreen()));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.history, color: C.accent),
                title: Text('Chat history', style: TextStyle(color: C.text)),
                trailing: Icon(Icons.chevron_right, color: C.muted),
                onTap: () {
                  final nav = Navigator.of(rootContext, rootNavigator: true);
                  Navigator.pop(context);
                  nav.push(MaterialPageRoute(builder: (_) => const ChatHistoryScreen()));
                },
              ),
              const SizedBox(height: 16),

              // ---------- account ----------
              _section('ACCOUNT'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.sync, color: C.muted),
                title: Text('Sync with Google', style: TextStyle(color: C.text)),
                subtitle: Text('Calendar and Classroom import', style: TextStyle(color: C.muted, fontSize: 12)),
                trailing: Pill('Soon', C.accent),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.alternate_email, color: C.muted),
                title: Text('Change email', style: TextStyle(color: C.text)),
                subtitle: Text(p?.email ?? '', style: TextStyle(color: C.muted, fontSize: 12)),
                onTap: () => _changeEmail(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.lock_reset, color: C.muted),
                title: Text('Change password', style: TextStyle(color: C.text)),
                onTap: () => _changePassword(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restart_alt, color: C.red),
                title: const Text('Reset account data', style: TextStyle(color: C.red)),
                subtitle: Text('Deletes all tasks, chats, streaks and badges. Your login stays.',
                    style: TextStyle(color: C.muted, fontSize: 12)),
                onTap: () => _confirmReset(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout, color: C.red),
                title: const Text('Sign out', style: TextStyle(color: C.red)),
                onTap: () async {
                  final nav = Navigator.of(rootContext, rootNavigator: true);
                  ClutchAgent.instance.resetConversation();
                  await state.signOut();
                  nav.pushAndRemoveUntil(fadeRoute(const AuthScreen()), (_) => false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changeEmail(BuildContext context) async {
    final email = TextEditingController(text: AppState.instance.profile?.email ?? '');
    final pw = TextEditingController();
    await _formDialog(
      context,
      title: 'Change email',
      fields: [
        _dialogField(email, 'New email', keyboard: TextInputType.emailAddress),
        _dialogField(pw, 'Current password', obscure: true),
      ],
      onSave: () => AppState.instance.changeEmail(email.text, pw.text),
      success: 'Email updated.',
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    await _formDialog(
      context,
      title: 'Change password',
      fields: [
        _dialogField(current, 'Current password', obscure: true),
        _dialogField(next, 'New password', obscure: true),
        _dialogField(confirm, 'Confirm new password', obscure: true),
      ],
      onSave: () async {
        if (next.text != confirm.text) return 'New passwords do not match.';
        return AppState.instance.changePassword(current.text, next.text);
      },
      success: 'Password changed.',
    );
  }

  Widget _dialogField(TextEditingController c, String label,
          {bool obscure = false, TextInputType keyboard = TextInputType.text}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          obscureText: obscure,
          keyboardType: keyboard,
          style: TextStyle(color: C.text),
          decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: C.muted)),
        ),
      );

  /// Small form dialog. [onSave] returns an error message, or null on success.
  Future<void> _formDialog(BuildContext context,
      {required String title,
      required List<Widget> fields,
      required Future<String?> Function() onSave,
      required String success}) async {
    final messenger = ScaffoldMessenger.of(context);
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: C.surface,
          title: Text(title, style: heading(20)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ...fields,
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(error!, style: const TextStyle(color: C.red, fontSize: 13)),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: C.muted))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.accent, foregroundColor: C.onAccent),
              onPressed: () async {
                final err = await onSave();
                if (err != null) {
                  setLocal(() => error = err);
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
                messenger.showSnackBar(SnackBar(content: Text(success)));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        title: Text('Reset account data?', style: heading(20)),
        content: Text(
            'All tasks, chats, streaks and badges will be deleted. Your login and settings stay. This cannot be undone.',
            style: TextStyle(color: C.muted, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: C.muted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset', style: TextStyle(color: C.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) {
      ClutchAgent.instance.resetConversation();
      await AppState.instance.resetAccountData();
      if (context.mounted) Navigator.pop(context);
    }
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label, style: TextStyle(color: C.muted, fontSize: 12, letterSpacing: 1.2)),
      );

  Future<void> _editProfile(BuildContext context) async {
    final state = AppState.instance;
    final p = state.profile;
    if (p == null) return;
    final name = TextEditingController(text: p.name);
    final college = TextEditingController(text: p.college);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        title: Text('Edit profile', style: heading(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              style: TextStyle(color: C.text),
              decoration: InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: C.muted))),
          TextField(
              controller: college,
              style: TextStyle(color: C.text),
              decoration: InputDecoration(labelText: 'College', labelStyle: TextStyle(color: C.muted))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: C.muted))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.accent, foregroundColor: C.onAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await state.updateProfile(name: name.text, college: college.text);
      ClutchAgent.instance.resetConversation();
    }
  }
}
