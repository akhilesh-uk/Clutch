# CLUTCH — Your Deadline Survival Agent

Talk to CLUTCH about your deadlines. Gemini understands what you say, a deterministic Dart engine ranks and schedules the work, and CLUTCH answers in your own cloned ElevenLabs voice.

## Run it (about 10 minutes)

Needs Flutter 3.27 or newer and an Android phone with USB debugging on.

```bash
cd clutch
flutter create --platforms android --org com.akhilesh .   # adds the android/ folder, keeps lib/
python tool/setup_android.py                             # mic + internet permissions, minSdk 24
cp keys.example.json keys.json                           # then paste your keys into keys.json
flutter pub get
flutter run --dart-define-from-file=keys.json
```

On Windows use `copy keys.example.json keys.json`.

### keys.json

| Key | Where to get it |
| --- | --- |
| `GEMINI_API_KEY` | Google AI Studio |
| `GEMINI_MODEL` | Default `gemini-3.8-flash`. If Gemini returns 404, use the model name its error message suggests |
| `ELEVEN_API_KEY` | ElevenLabs, Developers, API keys (needs text-to-speech and speech-to-text access) |
| `ELEVEN_VOICE_ID` | ElevenLabs, Voices, your cloned voice, copy its ID |
| `ELEVEN_TTS_MODEL` | Default `eleven_flash_v2_5` (fast). Falls back to `eleven_multilingual_v2` automatically |
| `ELEVEN_STT_MODEL` | Default `scribe_v2`. Falls back to `scribe_v1` automatically |

`keys.json` is in `.gitignore`. The keys are compiled into the APK, so don't share the APK publicly.

### Release APK for the demo phone

```bash
flutter build apk --release --dart-define-from-file=keys.json
# build/app/outputs/flutter-apk/app-release.apk
```

## App flow

Animated splash → 3-page onboarding (first launch only) → sign in or create account → main app.

- **Accounts are local.** Sign-up details stay on the phone (password stored as a SHA-256 hash). "Continue with Google" and Google sync are marked *Soon*: they need a Firebase project and Google Cloud OAuth setup, planned for a future update.
- **Talk screen** starts a new chat every time (old chats under the history icon), opens with the CLUTCH logo and a spoken welcome, and types your words live into the box as you speak (phone speech recognition).
- **Voice replies** use ElevenLabs when the voice ID works on your plan, otherwise the phone's own voice. On the free ElevenLabs plan use a `premade` voice ID.
- **Tutorial** (Settings) runs a guided tour on a demo week, then restores your own data.
- **Settings:** profile, dark/light mode, accent colour, CLUTCH personality, voice replies, study window, tutorial, chat history, change email or password, reset account data, sign out.

## Free vs Ultra Pro

| | Free | Ultra Pro |
|---|---|---|
| Assistant brain | Gemini | Claude (`CLAUDE_MODEL`, default `claude-sonnet-5-5`), falls back to Gemini if Claude fails |
| Task effort | Your estimate or Gemini's | Claude splits each task into steps and estimates the real time (`CLAUDE_FAST_MODEL`, default `claude-haiku-5-5`) |
| Day plan | Ranked blocks | Blocks labelled with the AI step, plus an AI day plan that rewrites itself when tasks change |
| Voice | Phone voice | Any ElevenLabs voice on your account, picked in Settings |

Payments are not wired up: Ultra Pro activates in demo mode from Settings → Plan. Add `CLAUDE_API_KEY` to keys.json for the Claude features.

## How it works

```
Mic -> ElevenLabs speech-to-text -> Gemini (function calling) -> Dart engine -> screens
                                         |                                       |
                                         +-> short reply -> ElevenLabs voice <---+
```

- `lib/engine/engine.dart` ranks tasks by slack and importance, fills each day's free hours, and colours days green, yellow or red. Gemini never does this maths.
- `lib/services/clutch_agent.dart` gives Gemini 8 tools: `get_overview`, `add_tasks`, `update_task`, `mark_done`, `mark_missed`, `preview_today_limit`, `set_today_limit` and `delete_task`.
- `lib/state/app_state.dart` stores everything on the phone and re-runs the engine after every change.

## Demo script

1. Settings, **Load demo week** (or start empty and speak your week).
2. Tap the mic: *"I have a DBMS assignment due Friday, the ML lab record by Thursday, and an OS internal tomorrow morning."*
3. Survival tab: the ranked plan, with a reason on every block.
4. Mic: *"I'm exhausted, can I skip the OS prep tonight?"* CLUTCH previews the damage and offers a compromise.
5. Tap **Missed** on the Now card, then open Calendar to see a day turn red.
6. **Brief me** on the Survival tab: a spoken summary of the day.

Rehearse the demo lines once on venue Wi-Fi. Every spoken reply is cached, so repeated lines play instantly.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `pub get` version conflict | `flutter pub upgrade --major-versions` |
| Gemini error 404 | Your key can't use that model. Change `GEMINI_MODEL` |
| Gemini or ElevenLabs error 401 | Wrong key, or keys.json wasn't passed to `flutter run` |
| "Microphone permission is needed" | Allow the mic in Android settings for CLUTCH |
| Nothing planned today | Your free window (Settings) has already ended for today. Widen it for the demo |
