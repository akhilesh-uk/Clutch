import 'dart:async';

import 'package:flutter/material.dart';

import '../services/eleven_labs.dart';
import '../services/voice_io.dart';
import '../theme.dart';

/// Small recorder dialog. Records, transcribes, and returns the text
/// (or null if cancelled). Nothing is sent: the caller puts the text in
/// the input box so the user can review it first.
Future<String?> showRecorder(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RecorderDialog(),
  );
}

enum _RecState { starting, recording, transcribing, error }

class _RecorderDialog extends StatefulWidget {
  _RecorderDialog();

  @override
  State<_RecorderDialog> createState() => _RecorderDialogState();
}

class _RecorderDialogState extends State<_RecorderDialog> with SingleTickerProviderStateMixin {
  static const _maxSeconds = 60;
  final _voice = VoiceIO.instance;
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: Duration(milliseconds: 900))..repeat(reverse: true);
  _RecState _state = _RecState.starting;
  String _error = '';
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final ok = await _voice.startRecording();
      if (!mounted) return;
      if (!ok) {
        _fail('Microphone permission is needed. Allow it in Android settings.');
        return;
      }
      setState(() => _state = _RecState.recording);
      _timer = Timer.periodic(Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= _maxSeconds) _done();
      });
    } catch (e) {
      _fail('Could not start the mic: $e');
    }
  }

  void _fail(String message) {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _state = _RecState.error;
        _error = message;
      });
    }
  }

  Future<void> _done() async {
    if (_state != _RecState.recording) return;
    _timer?.cancel();
    setState(() => _state = _RecState.transcribing);
    try {
      final path = await _voice.stopRecording();
      if (path == null) throw Exception('No audio was recorded.');
      final text = await ElevenLabs.transcribe(path);
      if (!mounted) return;
      if (text.isEmpty) {
        _fail("Didn't catch that. Try again a little closer to the mic.");
        return;
      }
      Navigator.of(context).pop(text);
    } catch (e) {
      _fail('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    await _voice.cancelRecording();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String get _clock => '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final recording = _state == _RecState.recording;
    final title = switch (_state) {
      _RecState.starting => 'Starting mic…',
      _RecState.recording => 'Listening…',
      _RecState.transcribing => 'Turning speech into text…',
      _RecState.error => 'Something went wrong',
    };

    return Dialog(
      backgroundColor: C.surface,
      insetPadding: EdgeInsets.symmetric(horizontal: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: C.border),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: heading(18)),
          SizedBox(height: 20),
          SizedBox(
            height: 96,
            child: Center(
              child: _state == _RecState.error
                  ? Icon(Icons.mic_off, color: C.red, size: 44)
                  : _state == _RecState.transcribing || _state == _RecState.starting
                      ? SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(strokeWidth: 3, color: C.accent))
                      : AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, __) => Container(
                            width: 64 + 18 * _pulse.value,
                            height: 64 + 18 * _pulse.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: C.accent.withValues(alpha: 0.15 + 0.15 * _pulse.value),
                            ),
                            child: Center(
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: C.accent),
                                child: Icon(Icons.mic, color: C.onAccent, size: 28),
                              ),
                            ),
                          ),
                        ),
            ),
          ),
          SizedBox(height: 12),
          if (recording)
            Text('$_clock  ·  Speak, then tap Done',
                style: TextStyle(color: C.muted, fontSize: 13)),
          if (_state == _RecState.error)
            Text(_error,
                textAlign: TextAlign.center,
                style: TextStyle(color: C.muted, fontSize: 13, height: 1.4)),
          SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextButton(
                onPressed: _state == _RecState.transcribing ? null : _cancel,
                child: Text(_state == _RecState.error ? 'Close' : 'Cancel',
                    style: TextStyle(color: C.muted)),
              ),
            ),
            if (_state != _RecState.error) ...[
              SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: C.accent, foregroundColor: C.onAccent),
                  onPressed: recording ? _done : null,
                  child: Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}
