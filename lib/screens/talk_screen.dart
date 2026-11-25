import 'package:flutter/material.dart';

import '../models/settings.dart';
import '../services/clutch_agent.dart';
import '../services/speaker.dart';
import '../services/voice_io.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'chat_history_screen.dart';
import 'plans_screen.dart';

/// Opens CLUTCH chat. A new conversation every time, unless
/// [conversationId] continues a saved one.
void openTalk(BuildContext context, {bool autoListen = false, String? initialText, String? conversationId}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) =>
        TalkScreen(autoListen: autoListen, initialText: initialText, conversationId: conversationId),
  ));
}

enum Phase { idle, thinking, speaking }

class TalkScreen extends StatefulWidget {
  final bool autoListen;
  final String? initialText;
  final String? conversationId;
  const TalkScreen({super.key, this.autoListen = false, this.initialText, this.conversationId});

  @override
  State<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends State<TalkScreen> with SingleTickerProviderStateMixin {
  final _state = AppState.instance;
  final _voice = VoiceIO.instance;
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  Phase _phase = Phase.idle;
  bool _listening = false;
  bool _fallbackNoted = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      if (mounted) setState(() {});
    });
    if (widget.conversationId != null) {
      _state.openConversation(widget.conversationId!, notify: false);
      ClutchAgent.instance.loadHistory(_state.chat);
    } else {
      _state.startNewChat(notify: false);
      ClutchAgent.instance.resetConversation();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.initialText != null) {
        _send(widget.initialText!);
        return;
      }
      if (widget.conversationId == null) await _greet();
      if (widget.autoListen && mounted) _toggleListening();
    });
  }

  @override
  void dispose() {
    _voice.stopListening();
    _voice.stopPlayback();
    _pulse.dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _set(Phase p) {
    if (mounted) setState(() => _phase = p);
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _note(String text) {
    _state.addChat(ChatRole.system, text);
    _toBottom();
  }

  Future<void> _speak(String text) async {
    if (!_state.settings.voiceReplies || !mounted) return;
    _set(Phase.speaking);
    try {
      await Speaker.say(text);
      final why = Speaker.lastFallbackReason;
      if (why != null && !_fallbackNoted) {
        _fallbackNoted = true;
        _note(why);
      }
    } catch (_) {
      // Speaking is a bonus; the text reply is already on screen.
    }
    if (_phase == Phase.speaking) _set(Phase.idle);
  }

  String get _greeting {
    final h = DateTime.now().hour;
    final part = h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
    final name = _state.profile?.firstName ?? 'there';
    return switch (_state.settings.personality) {
      Personality.witty =>
        "$part, $name! I'm CLUTCH, your deadline survival agent. Tell me what's due, and I'll get you out of it alive.",
      Personality.calm =>
        "$part, $name. I'm CLUTCH. Tell me what's on your plate, and we'll plan it calmly, one step at a time.",
      Personality.strict =>
        "$part, $name. CLUTCH here. Deadlines don't wait, so tell me what's due and let's get to work.",
    };
  }

  /// Spoken welcome, once per app launch.
  Future<void> _greet() async {
    if (_state.greetedThisSession) return;
    _state.greetedThisSession = true;
    await _speak(_greeting);
  }

  /// Live dictation: words appear in the input box as you speak.
  Future<void> _toggleListening() async {
    if (_listening) {
      await _voice.stopListening();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (_phase == Phase.thinking) return;
    await _voice.stopPlayback();
    if (_phase == Phase.speaking) _set(Phase.idle);
    final base = _input.text.trim();
    final ok = await _voice.startListening(
      onText: (words) {
        if (!mounted) return;
        _input.text = base.isEmpty ? words : '$base $words';
        _input.selection = TextSelection.collapsed(offset: _input.text.length);
      },
      onStopped: () {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!mounted) return;
    if (!ok) {
      _note('Speech recognition is not available on this phone. Allow the microphone, or type instead.');
      return;
    }
    setState(() => _listening = true);
  }

  Future<void> _send(String text) async {
    final t = text.trim();
    if (t.isEmpty || _phase == Phase.thinking) return;
    if (_listening) {
      await _voice.stopListening();
      _listening = false;
    }
    _input.clear();
    _focus.unfocus();
    await _voice.stopPlayback();
    _state.addChat(ChatRole.user, t);
    _toBottom();
    _set(Phase.thinking);
    try {
      final reply = await ClutchAgent.instance.send(t);
      _state.addChat(ChatRole.clutch, reply);
      _toBottom();
      _set(Phase.idle);
      await _speak(reply);
    } catch (e) {
      _note('$e'.replaceFirst('Exception: ', ''));
      _set(Phase.idle);
    }
  }

  void _stopSpeaking() {
    _voice.stopPlayback();
    _set(Phase.idle);
  }

  void _newChat() {
    _stopSpeaking();
    _state.startNewChat();
    ClutchAgent.instance.resetConversation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          ClutchWordmark(size: 20),
          if (_state.settings.ultra) ...[const SizedBox(width: 8), const UltraBadge(size: 8)],
        ]),
        actions: [
          IconButton(
            tooltip: 'Chat history',
            icon: Icon(Icons.history, color: C.muted),
            onPressed: () {
              _stopSpeaking();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatHistoryScreen()));
            },
          ),
          IconButton(
            tooltip: 'New chat',
            icon: Icon(Icons.add_comment_outlined, color: C.muted),
            onPressed: _newChat,
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListenableBuilder(
            listenable: _state,
            builder: (context, _) {
              final msgs = _state.chat;
              if (msgs.isEmpty) return _welcome();
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: msgs.length,
                itemBuilder: (_, i) => _Bubble(msgs[i]),
              );
            },
          ),
        ),
        _statusBar(),
        _inputBar(),
      ]),
    );
  }

  Widget _welcome() {
    final name = _state.profile?.firstName ?? 'there';
    final chips = <(IconData, String, VoidCallback)>[
      (Icons.wb_sunny_outlined, 'Brief me on today', () => _send('Give me my briefing for today.')),
      (Icons.mic_none, 'Add my deadlines by voice', _toggleListening),
      (Icons.bolt, 'What should I do right now?', () => _send('What should I do right now?')),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      children: [
        const SizedBox(height: 12),
        Center(child: ClutchLogo(width: 150)),
        const SizedBox(height: 24),
        Text('Hey $name,', textAlign: TextAlign.center, style: heading(28)),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: "I'm "),
            TextSpan(text: 'CLUTCH', style: TextStyle(color: C.accent, fontWeight: FontWeight.w800)),
            const TextSpan(text: ', your deadline survival agent.'),
          ]),
          textAlign: TextAlign.center,
          style: TextStyle(color: C.text, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          "Tap the mic and tell me what's due, the way you'd tell a friend. I'll plan it and tell you what to do first.",
          textAlign: TextAlign.center,
          style: TextStyle(color: C.muted, height: 1.5),
        ),
        const SizedBox(height: 28),
        for (final c in chips)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onTap: _phase == Phase.thinking ? null : c.$3,
              child: Row(children: [
                Icon(c.$1, color: C.accent, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(c.$2, style: TextStyle(color: C.text, fontWeight: FontWeight.w600))),
                Icon(Icons.chevron_right, color: C.muted),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _statusBar() {
    String? label;
    Widget? icon;
    if (_listening) {
      label = 'Listening… speak, then tap the mic or send';
      icon = Icon(Icons.graphic_eq, color: C.red, size: 18);
    } else if (_phase == Phase.thinking) {
      label = 'CLUTCH is thinking…';
      icon = SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: C.accent));
    } else if (_phase == Phase.speaking) {
      label = 'CLUTCH is speaking';
      icon = Icon(Icons.volume_up, color: C.accent, size: 18);
    }
    if (label == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(children: [
        icon!,
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(color: C.muted, fontSize: 13))),
        if (_phase == Phase.speaking)
          TextButton(onPressed: _stopSpeaking, child: Text('Stop', style: TextStyle(color: C.accent))),
      ]),
    );
  }

  Widget _inputBar() {
    final hasText = _input.text.trim().isNotEmpty;
    final busy = _phase == Phase.thinking;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _input,
              focusNode: _focus,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              style: TextStyle(color: C.text),
              decoration: InputDecoration(
                hintText: _listening ? 'Listening…' : 'Type or tap the mic…',
                hintStyle: TextStyle(color: C.muted),
                filled: true,
                fillColor: C.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: C.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: _listening ? C.red : C.border, width: _listening ? 1.5 : 1)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: C.accent)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Transform.scale(
              scale: _listening ? 1 + 0.08 * _pulse.value : 1,
              child: _roundButton(
                icon: _listening ? Icons.stop_rounded : Icons.mic,
                filled: _listening || !hasText,
                color: _listening ? C.red : null,
                onTap: busy ? null : _toggleListening,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _roundButton(
            icon: Icons.arrow_upward_rounded,
            filled: hasText && !_listening,
            onTap: (hasText && !busy) ? () => _send(_input.text) : null,
          ),
        ]),
      ),
    );
  }

  Widget _roundButton({required IconData icon, required bool filled, VoidCallback? onTap, Color? color}) {
    final enabled = onTap != null;
    final base = color ?? C.accent;
    return Material(
      color: filled && enabled ? base : C.surface2,
      shape: CircleBorder(side: BorderSide(color: enabled ? base : C.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: !enabled ? C.muted : (filled ? C.onAccent : base), size: 22),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage m;
  const _Bubble(this.m);

  @override
  Widget build(BuildContext context) {
    if (m.role == ChatRole.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(m.text,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: C.muted, fontSize: 12)),
      );
    }
    final mine = m.role == ChatRole.user;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: mine ? C.accent : C.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          border: mine ? null : Border.all(color: C.border),
        ),
        child: Text(m.text, style: TextStyle(color: mine ? C.onAccent : C.text, height: 1.4, fontSize: 15)),
      ),
    );
  }
}
