"""One-time Android setup. Run from the project folder AFTER `flutter create`:

    python tool/setup_android.py

Adds the internet and microphone permissions, names the app CLUTCH,
and raises minSdk to 24 (needed by the audio recorder).
"""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
manifest = root / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
if not manifest.exists():
    sys.exit("android/ folder not found. Run: flutter create --platforms android --org com.akhilesh .")

text = manifest.read_text(encoding="utf-8")
perms = [
    '<uses-permission android:name="android.permission.INTERNET"/>',
    '<uses-permission android:name="android.permission.RECORD_AUDIO"/>',
]
missing = [p for p in perms if p.split('"')[1] not in text]
if missing:
    text = re.sub(r"(<manifest[^>]*>)", lambda m: m.group(1) + "\n    " + "\n    ".join(missing), text, count=1)
text = re.sub(r'android:label="[^"]*"', 'android:label="CLUTCH"', text, count=1)
# Android 11+ needs to declare the speech recogniser and text-to-speech services.
intents = {
    "android.speech.RecognitionService": "<intent><action android:name=\"android.speech.RecognitionService\"/></intent>",
    "android.intent.action.TTS_SERVICE": "<intent><action android:name=\"android.intent.action.TTS_SERVICE\"/></intent>",
}
add = "".join("\n        " + xml for name, xml in intents.items() if name not in text)
if add:
    if "<queries>" in text:
        text = text.replace("<queries>", "<queries>" + add, 1)
    else:
        text = text.replace("</manifest>", "    <queries>" + add + "\n    </queries>\n</manifest>", 1)
    print("Manifest: speech and TTS service queries added")
manifest.write_text(text, encoding="utf-8")
print("Manifest: permissions and label set")

for name in ("build.gradle.kts", "build.gradle"):
    gradle = root / "android" / "app" / name
    if gradle.exists():
        g = gradle.read_text(encoding="utf-8")
        g2 = g.replace("flutter.minSdkVersion", "24")
        gradle.write_text(g2, encoding="utf-8")
        print(f"{name}: minSdk set to 24" if g2 != g else f"{name}: minSdk already set, check it is 24 or higher")
        break
props = root / "android" / "gradle.properties"
if props.exists():
    ptxt = props.read_text(encoding="utf-8")
    if "kotlin.incremental" not in ptxt:
        # Kotlin incremental builds break on Windows when the project and the
        # pub cache are on different drives (e.g. D: and C:).
        props.write_text(ptxt.rstrip("\n") + "\nkotlin.incremental=false\n", encoding="utf-8")
        print("gradle.properties: Kotlin incremental compilation off")

default_test = root / "test" / "widget_test.dart"
if default_test.exists() and "MyApp" in default_test.read_text(encoding="utf-8"):
    default_test.unlink()  # flutter create's counter-app test does not apply to CLUTCH
    print("Removed the default counter-app test")

print("Done. Next: flutter pub get, then flutter run --dart-define-from-file=keys.json")
