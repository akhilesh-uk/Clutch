import 'package:flutter/material.dart';

import '../services/eleven_labs.dart';
import '../services/voice_io.dart';
import '../state/app_state.dart';
import '../theme.dart';

void openVoicePicker(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VoicePickerScreen()));
}

/// Ultra Pro: choose the ElevenLabs voice CLUTCH speaks with.
class VoicePickerScreen extends StatefulWidget {
  const VoicePickerScreen({super.key});

  @override
  State<VoicePickerScreen> createState() => _VoicePickerScreenState();
}

class _VoicePickerScreenState extends State<VoicePickerScreen> {
  late Future<List<ElevenVoice>> _voices = ElevenLabs.listVoices();
  String? _playing;

  @override
  void dispose() {
    VoiceIO.instance.stopPlayback();
    super.dispose();
  }

  Future<void> _preview(ElevenVoice v) async {
    if (v.previewUrl == null) return;
    if (_playing == v.id) {
      await VoiceIO.instance.stopPlayback();
      setState(() => _playing = null);
      return;
    }
    setState(() => _playing = v.id);
    try {
      await VoiceIO.instance.playUrl(v.previewUrl!);
    } catch (_) {
      if (mounted) setState(() => _playing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: Text('Choose CLUTCH\'s voice', style: heading(20))),
      body: FutureBuilder<List<ElevenVoice>>(
        future: _voices,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator(color: C.accent));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${snap.error}'.replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center, style: TextStyle(color: C.muted)),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _voices = ElevenLabs.listVoices()),
                    child: Text('Try again', style: TextStyle(color: C.accent)),
                  ),
                ]),
              ),
            );
          }
          final voices = snap.data!;
          return ListenableBuilder(
            listenable: state,
            builder: (context, _) => ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: voices.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Tap play to hear a voice, then tap it to choose. On the free ElevenLabs plan, use voices marked premade.',
                      style: TextStyle(color: C.muted, fontSize: 13, height: 1.4),
                    ),
                  );
                }
                final v = voices[i - 1];
                final selected = state.settings.voiceId == v.id;
                return Panel(
                  borderColor: selected ? C.accent : null,
                  borderWidth: selected ? 1.6 : 1,
                  onTap: () {
                    state.setVoice(v.id, v.name.split(' - ').first);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('CLUTCH will now speak as ${v.name.split(' - ').first}.')));
                  },
                  child: Row(children: [
                    IconButton(
                      onPressed: v.previewUrl == null ? null : () => _preview(v),
                      icon: Icon(_playing == v.id ? Icons.stop_circle : Icons.play_circle_fill,
                          color: C.accent, size: 36),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(
                            child: Text(v.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: C.text, fontWeight: FontWeight.w700)),
                          ),
                          if (v.category.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Pill(v.category, v.category == 'premade' ? C.green : C.muted),
                          ],
                        ]),
                        if (v.labels.isNotEmpty)
                          Text(v.labels.take(4).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: C.muted, fontSize: 12)),
                      ]),
                    ),
                    if (selected) Icon(Icons.check_circle, color: C.accent),
                  ]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
