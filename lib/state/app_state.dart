import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../demo/seed.dart';
import '../engine/engine.dart';
import '../engine/format.dart';
import '../engine/streaks.dart';
import '../models/profile.dart';
import '../models/settings.dart';
import '../models/task.dart';
import '../services/ultra_ai.dart';
import '../theme.dart';

enum ChatRole { user, clutch, system }

class ChatMessage {
  final ChatRole role;
  final String text;
  final DateTime at;
  ChatMessage(this.role, this.text, {DateTime? at}) : at = at ?? DateTime.now();

  Map<String, dynamic> toJson() => {'role': role.name, 'text': text, 'at': at.toIso8601String()};

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        ChatRole.values.firstWhere((r) => r.name == j['role'], orElse: () => ChatRole.system),
        (j['text'] ?? '') as String,
        at: DateTime.tryParse((j['at'] ?? '') as String),
      );
}

/// One chat session with CLUTCH. Every visit to the talk screen starts a new one.
class Conversation {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<ChatMessage> messages;

  Conversation(this.id, {this.title = 'New chat', DateTime? createdAt, List<ChatMessage>? messages})
      : createdAt = createdAt ?? DateTime.now(),
        updatedAt = createdAt ?? DateTime.now(),
        messages = messages ?? [];

  bool get hasUserMessage => messages.any((m) => m.role == ChatRole.user);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory Conversation.fromJson(Map<String, dynamic> j) {
    final c = Conversation(
      j['id'] as String,
      title: (j['title'] ?? 'Chat') as String,
      createdAt: DateTime.tryParse((j['createdAt'] ?? '') as String),
      messages: ((j['messages'] as List?) ?? const [])
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
    c.updatedAt = DateTime.tryParse((j['updatedAt'] ?? '') as String) ?? c.createdAt;
    return c;
  }
}

/// Single source of truth. Every change saves and re-runs the engine,
/// so all screens always show the same plan.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  final List<Task> tasks = [];
  AppSettings settings = AppSettings();
  PlanResult plan = PlanResult.empty();
  final List<Conversation> conversations = []; // newest first
  Conversation? current;
  List<ChatMessage> get chat => current?.messages ?? const [];
  bool inTutorial = false;
  Profile? profile;
  bool onboarded = false;

  /// Set once the spoken welcome has played, so it plays once per app launch.
  bool greetedThisSession = false;

  bool get signedIn => profile?.signedIn ?? false;

  // ---------- streaks and badges ----------
  final Map<String, DayRecord> dayLog = {};
  final Set<String> _overdueLogged = {};
  DateTime trackingSince = dayOf(DateTime.now());
  final Set<String> earnedBadges = {};
  StreakStats stats = StreakStats(0, 0, 0, 0, const []);

  /// Lets the state show a snackbar (badge unlocked) from anywhere.
  final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  SharedPreferences? _prefs;
  Timer? _ticker;
  int _idCounter = 0;

  Engine get engine => Engine(settings);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final rawTasks = _prefs!.getString('tasks');
    final rawSettings = _prefs!.getString('settings');
    if (rawSettings != null) {
      settings = AppSettings.fromJson(jsonDecode(rawSettings) as Map<String, dynamic>);
    }
    final rawProfile = _prefs!.getString('profile');
    if (rawProfile != null) {
      profile = Profile.fromJson(jsonDecode(rawProfile) as Map<String, dynamic>);
    }
    onboarded = _prefs!.getBool('onboarded') ?? false;
    // Ultra Pro ships in the next update; this version always runs Free.
    settings.tier = Tier.free;
    final rawChats = _prefs!.getString('chats');
    if (rawChats != null) {
      conversations.addAll((jsonDecode(rawChats) as List)
          .map((c) => Conversation.fromJson(c as Map<String, dynamic>)));
    }
    final rawLog = _prefs!.getString('dayLog');
    if (rawLog != null) {
      final m = jsonDecode(rawLog) as Map<String, dynamic>;
      m.forEach((k, v) => dayLog[k] = DayRecord.fromJson(v as Map<String, dynamic>));
    }
    _overdueLogged.addAll(_prefs!.getStringList('overdueLogged') ?? const []);
    earnedBadges.addAll(_prefs!.getStringList('badges') ?? const []);
    final since = DateTime.tryParse(_prefs!.getString('trackingSince') ?? '');
    if (since != null) {
      trackingSince = since;
    } else {
      await _prefs!.setString('trackingSince', trackingSince.toIso8601String());
    }
    _applyTheme();
    if (rawTasks != null) {
      final list = jsonDecode(rawTasks) as List;
      tasks
        ..clear()
        ..addAll(list.map((e) => Task.fromJson(e as Map<String, dynamic>)));
    }
    final backup = _prefs!.getString('tutorialBackup');
    if (backup != null) _restoreBackup(backup);
    recompute();
    _maybeRefreshDayPlan();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) => recompute());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void recompute() {
    final now = DateTime.now();
    plan = engine.compute(tasks, now);
    _logOverdue(now);
    stats = computeStreaks(now, trackingSince, dayLog);
    notifyListeners();
  }

  DayRecord _day(DateTime d) => dayLog.putIfAbsent(dayKey(d), () => DayRecord());

  /// A deadline that passed with the task unfinished turns its due day red.
  void _logOverdue(DateTime now) {
    var changed = false;
    for (final t in tasks) {
      if (t.isDone || t.dueAt.isAfter(now) || _overdueLogged.contains(t.id)) continue;
      _overdueLogged.add(t.id);
      if (!dayOf(t.dueAt).isBefore(dayOf(trackingSince))) {
        _day(t.dueAt).overdue++;
      }
      changed = true;
    }
    if (changed) _saveStreaks();
  }

  Future<void> _saveStreaks() async {
    await _prefs?.setString('dayLog', jsonEncode(dayLog.map((k, v) => MapEntry(k, v.toJson()))));
    await _prefs?.setStringList('overdueLogged', _overdueLogged.toList());
    await _prefs?.setStringList('badges', earnedBadges.toList());
    await _prefs?.setString('trackingSince', trackingSince.toIso8601String());
  }

  void _checkBadges() {
    final fresh = stats.earned.difference(earnedBadges);
    if (fresh.isEmpty) return;
    earnedBadges.addAll(fresh);
    _saveStreaks();
    final names = badgeDefs.where((b) => fresh.contains(b.id)).map((b) => b.title).join(' + ');
    messengerKey.currentState?.showSnackBar(SnackBar(
      duration: const Duration(seconds: 4),
      content: Row(children: [
        Icon(Icons.emoji_events, color: C.accent),
        const SizedBox(width: 12),
        Expanded(child: Text('Badge unlocked: $names')),
      ]),
    ));
  }

  void _applyTheme() {
    C.dark = settings.darkMode;
    C.accentIndex = settings.accentIndex;
  }

  Future<void> _save() async {
    await _prefs?.setString('tasks', jsonEncode(tasks.map((t) => t.toJson()).toList()));
    await _prefs?.setString('settings', jsonEncode(settings.toJson()));
  }

  void _commit() {
    recompute();
    _maybeRefreshDayPlan();
    _checkBadges();
    _save();
    _saveStreaks();
  }

  String newId() =>
      '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${(_idCounter++).toRadixString(36)}';

  Task? byId(String id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<Task> get openTasks {
    final open = tasks.where((t) => !t.isDone).toList();
    open.sort((a, b) => (plan.insights[b.id]?.priority ?? 0)
        .compareTo(plan.insights[a.id]?.priority ?? 0));
    return open;
  }

  // ---------- actions (used by UI and by the Gemini agent) ----------

  void addTasks(List<Task> newTasks) {
    tasks.addAll(newTasks);
    _commit();
    // Ultra Pro: the AI works out real effort and steps, then the plan updates.
    if (settings.ultra) {
      for (final t in newTasks) {
        analyzeTask(t.id);
      }
    }
  }

  // ---------- Ultra Pro ----------

  String? aiDayPlan;
  bool aiDayPlanLoading = false;
  String _dayPlanSig = '';
  Timer? _dayPlanDebounce;

  Future<void> setTier(Tier tier) async {
    settings.tier = tier;
    _applyTheme();
    _commit();
    if (tier == Tier.ultra) {
      for (final t in tasks.where((t) => !t.isDone && !t.aiAnalyzed).toList()) {
        analyzeTask(t.id);
      }
    } else {
      aiDayPlan = null;
      _dayPlanSig = '';
    }
  }

  void setVoice(String id, String name) {
    updateSettings((x) {
      x.voiceId = id;
      x.voiceName = name;
    });
  }

  /// Claude analyses the task: steps, real time needed, importance.
  Future<void> analyzeTask(String id) async {
    final t = byId(id);
    if (t == null || t.aiAnalyzing) return;
    t.aiAnalyzing = true;
    notifyListeners();
    try {
      final a = await UltraAI.analyze(t);
      final cur = byId(id);
      if (a != null && cur != null) {
        cur.aiSteps = a.steps;
        cur.aiSummary = a.summary;
        cur.aiDifficulty = a.difficulty;
        if (cur.notes.isEmpty) cur.notes = a.summary;
        cur.estHours = a.hours < cur.doneHours ? cur.doneHours : a.hours;
        if (a.importance != null && !cur.importanceReason.startsWith('Set by you')) {
          cur.importance = a.importance!;
          if (a.importanceReason.isNotEmpty) cur.importanceReason = a.importanceReason;
        }
      }
    } catch (e) {
      debugPrint('Task analysis failed: $e');
    } finally {
      byId(id)?.aiAnalyzing = false;
      _commit();
    }
  }

  String get _toneLine => switch (settings.personality) {
        Personality.witty => 'Sound like a sharp, slightly witty coach on the student\'s side.',
        Personality.calm => 'Sound like a calm, reassuring mentor.',
        Personality.strict => 'Sound like a strict, no-nonsense trainer.',
      };

  /// Re-writes the AI day plan whenever today's schedule changes.
  void _maybeRefreshDayPlan() {
    if (!settings.ultra || inTutorial) return;
    final now = DateTime.now();
    final today = plan.blocksOn(now);
    final sig = '${dayKey(now)}|${today.map((b) => '${b.taskId}${b.start.millisecondsSinceEpoch}${b.step}').join(',')}'
        '|${tasks.length}';
    if (sig == _dayPlanSig) return;
    _dayPlanSig = sig;
    _dayPlanDebounce?.cancel();
    _dayPlanDebounce = Timer(const Duration(milliseconds: 1500), () => _writeDayPlan(today, now));
  }

  Future<void> _writeDayPlan(List<PlanBlock> today, DateTime now) async {
    aiDayPlanLoading = true;
    notifyListeners();
    try {
      final schedule = today.isEmpty
          ? 'Nothing planned for the rest of today.'
          : today.map((b) {
              final t = byId(b.taskId);
              final step = b.step == null ? '' : ' (step: ${b.step})';
              return '${hm(b.start)}-${hm(b.end)}: ${t?.title ?? '?'}$step. ${b.reason}';
            }).join('\n');
      final week = plan.days
          .take(7)
          .map((d) => '${dayLabel(d.date, now)}: ${levelName(d.level)}, ${(d.pressure * 100).round()}% load')
          .join('\n');
      aiDayPlan = await UltraAI.dayPlan(
        name: profile?.firstName ?? 'there',
        tone: _toneLine,
        schedule: schedule,
        week: week,
      );
    } catch (e) {
      debugPrint('Day plan failed: $e');
    } finally {
      aiDayPlanLoading = false;
      notifyListeners();
    }
  }

  void markDone(String id) {
    final t = byId(id);
    if (t == null) return;
    t.status = TaskStatus.done;
    t.doneHours = t.estHours;
    _day(DateTime.now()).done++;
    _commit();
  }

  void reopen(String id) {
    final t = byId(id);
    if (t == null) return;
    t.status = TaskStatus.pending;
    t.doneHours = 0;
    final today = _day(DateTime.now());
    if (today.done > 0) today.done--;
    _commit();
  }

  /// Skips this task for the rest of today. Returns what it did to the week.
  String markMissed(String id) {
    final t = byId(id);
    if (t == null) return 'Task not found.';
    final before = plan;
    t.missedCount += 1;
    t.limitDate = dayKey(DateTime.now());
    t.limitMinutes = 0;
    _day(DateTime.now()).skipped++;
    _commit();
    return Engine.describeImpact(before, plan, DateTime.now());
  }

  /// Limits today's work on a task to [minutes]. Returns the impact.
  String limitToday(String id, int minutes) {
    final t = byId(id);
    if (t == null) return 'Task not found.';
    final before = plan;
    t.limitDate = dayKey(DateTime.now());
    t.limitMinutes = minutes < 0 ? 0 : minutes;
    _commit();
    return Engine.describeImpact(before, plan, DateTime.now());
  }

  /// What-if: same as limitToday, but nothing is saved.
  PlanResult previewLimit(String id, int minutes) {
    final copies = tasks.map((t) => t.copy()).toList();
    for (final c in copies) {
      if (c.id == id) {
        c.limitDate = dayKey(DateTime.now());
        c.limitMinutes = minutes < 0 ? 0 : minutes;
      }
    }
    return engine.compute(copies, DateTime.now());
  }

  void updateTask(String id,
      {String? title,
      DateTime? dueAt,
      double? estHours,
      int? importance,
      double? doneHours,
      String? notes,
      String? subject,
      TaskType? type,
      String? importanceReason}) {
    final t = byId(id);
    if (t == null) return;
    if (title != null) t.title = title;
    if (notes != null) t.notes = notes;
    if (subject != null) t.subject = subject.isEmpty ? null : subject;
    if (type != null) t.type = type;
    if (importanceReason != null) t.importanceReason = importanceReason;
    if (dueAt != null && dueAt != t.dueAt) {
      t.dueAt = dueAt;
      _overdueLogged.remove(t.id);
    }
    if (estHours != null) t.estHours = estHours;
    if (importance != null) t.importance = importance.clamp(1, 5).toInt();
    if (doneHours != null) t.doneHours = doneHours;
    _commit();
  }

  void deleteTask(String id) {
    tasks.removeWhere((t) => t.id == id);
    _commit();
  }

  void updateSettings(void Function(AppSettings s) edit) {
    edit(settings);
    _applyTheme();
    _commit();
  }

  // ---------- onboarding and local account ----------

  static String _hash(String password) => sha256.convert(utf8.encode('clutch::$password')).toString();

  Future<void> _saveProfile() async {
    if (profile == null) {
      await _prefs?.remove('profile');
    } else {
      await _prefs?.setString('profile', jsonEncode(profile!.toJson()));
    }
  }

  Future<void> finishOnboarding() async {
    onboarded = true;
    await _prefs?.setBool('onboarded', true);
    notifyListeners();
  }

  /// Returns an error message, or null on success.
  Future<String?> signUp(String name, String email, String password, {String college = ''}) async {
    if (name.trim().isEmpty) return 'Please enter your name.';
    if (!email.contains('@') || !email.contains('.')) return 'Please enter a valid email.';
    if (password.length < 6) return 'Password needs at least 6 characters.';
    profile = Profile(
      name: name.trim(),
      email: email.trim().toLowerCase(),
      passwordHash: _hash(password),
      college: college.trim(),
      signedIn: true,
    );
    await _saveProfile();
    notifyListeners();
    return null;
  }

  Future<String?> signIn(String email, String password) async {
    final p = profile;
    if (p == null) return 'No account on this phone yet. Sign up first.';
    if (p.email != email.trim().toLowerCase() || p.passwordHash != _hash(password)) {
      return 'Email or password is incorrect.';
    }
    p.signedIn = true;
    await _saveProfile();
    notifyListeners();
    return null;
  }

  Future<void> signOut() async {
    profile?.signedIn = false;
    greetedThisSession = false;
    current = null;
    await _saveProfile();
    notifyListeners();
  }

  Future<void> updateProfile({String? name, String? college}) async {
    final p = profile;
    if (p == null) return;
    if (name != null && name.trim().isNotEmpty) p.name = name.trim();
    if (college != null) p.college = college.trim();
    await _saveProfile();
    notifyListeners();
  }

  void loadDemo() {
    final now = DateTime.now();
    tasks
      ..clear()
      ..addAll(demoTasks(now, newId));
    // Demo history: four green days before today, one task finished each day.
    trackingSince = addDays(dayOf(now), -4);
    dayLog.clear();
    _overdueLogged.clear();
    earnedBadges.clear();
    for (var i = 1; i <= 4; i++) {
      dayLog[dayKey(addDays(now, -i))] = DayRecord(done: 1);
    }
    _commit();
  }

  // ---------- chats ----------

  Future<void> _saveChats() async {
    final keep = conversations.where((c) => c.hasUserMessage).take(30).toList();
    await _prefs?.setString('chats', jsonEncode(keep.map((c) => c.toJson()).toList()));
  }

  /// Starts a fresh conversation (created lazily on the first message).
  /// [notify] is false when called from a widget's initState.
  void startNewChat({bool notify = true}) {
    current = null;
    if (notify) notifyListeners();
  }

  void openConversation(String id, {bool notify = true}) {
    for (final c in conversations) {
      if (c.id == id) current = c;
    }
    if (notify) notifyListeners();
  }

  void deleteConversation(String id) {
    conversations.removeWhere((c) => c.id == id);
    if (current?.id == id) current = null;
    _saveChats();
    notifyListeners();
  }

  void addChat(ChatRole role, String text) {
    var c = current;
    if (c == null) {
      c = Conversation(newId());
      current = c;
      conversations.insert(0, c);
    }
    c.messages.add(ChatMessage(role, text));
    c.updatedAt = DateTime.now();
    if (role == ChatRole.user && c.title == 'New chat') {
      c.title = text.length > 48 ? '${text.substring(0, 48)}…' : text;
    }
    // Most recently used conversation first.
    conversations
      ..remove(c)
      ..insert(0, c);
    _saveChats();
    notifyListeners();
  }

  // ---------- task progress ----------

  /// Marks today's planned share of a task as done. Finishes the task if
  /// nothing is left. Returns a short summary.
  String completeToday(String id) {
    final t = byId(id);
    if (t == null) return 'Task not found.';
    final now = DateTime.now();
    var planned = 0.0;
    for (final b in plan.blocksOn(now)) {
      if (b.taskId == id) planned += b.hours;
    }
    if (planned <= 0) {
      final block = settings.blockMaxMinutes / 60.0;
      planned = t.remaining < block ? t.remaining : block;
    }
    final newDone = t.doneHours + planned;
    t.doneHours = newDone > t.estHours ? t.estHours : newDone;
    if (t.remaining <= 0.01) {
      t.status = TaskStatus.done;
      _day(now).done++;
      _commit();
      return '${t.title} is fully done. Nice work.';
    }
    // Today's share is done: plan nothing more for it today.
    t.limitDate = dayKey(now);
    t.limitMinutes = 0;
    _commit();
    return "Today's part done (${fmtH(planned)}). ${fmtH(t.remaining)} left for later days.";
  }

  // ---------- account ----------

  Future<String?> changeEmail(String newEmail, String currentPassword) async {
    final p = profile;
    if (p == null) return 'Not signed in.';
    if (p.passwordHash != _hash(currentPassword)) return 'Current password is incorrect.';
    final e = newEmail.trim().toLowerCase();
    if (!e.contains('@') || !e.contains('.')) return 'Please enter a valid email.';
    p.email = e;
    await _saveProfile();
    notifyListeners();
    return null;
  }

  Future<String?> changePassword(String currentPassword, String newPassword) async {
    final p = profile;
    if (p == null) return 'Not signed in.';
    if (p.passwordHash != _hash(currentPassword)) return 'Current password is incorrect.';
    if (newPassword.length < 6) return 'New password needs at least 6 characters.';
    p.passwordHash = _hash(newPassword);
    await _saveProfile();
    return null;
  }

  /// Wipes tasks, chats, streaks and badges. Keeps the account and settings.
  Future<void> resetAccountData() async {
    tasks.clear();
    conversations.clear();
    current = null;
    dayLog.clear();
    _overdueLogged.clear();
    earnedBadges.clear();
    trackingSince = dayOf(DateTime.now());
    await _saveChats();
    _commit();
  }

  // ---------- tutorial ----------

  String _snapshot() => jsonEncode({
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'dayLog': dayLog.map((k, v) => MapEntry(k, v.toJson())),
        'overdueLogged': _overdueLogged.toList(),
        'badges': earnedBadges.toList(),
        'trackingSince': trackingSince.toIso8601String(),
      });

  void _restoreBackup(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    tasks
      ..clear()
      ..addAll(((j['tasks'] as List?) ?? const []).map((e) => Task.fromJson(e as Map<String, dynamic>)));
    dayLog.clear();
    ((j['dayLog'] as Map?) ?? const {}).forEach(
        (k, v) => dayLog[k as String] = DayRecord.fromJson(Map<String, dynamic>.from(v as Map)));
    _overdueLogged
      ..clear()
      ..addAll(((j['overdueLogged'] as List?) ?? const []).cast<String>());
    earnedBadges
      ..clear()
      ..addAll(((j['badges'] as List?) ?? const []).cast<String>());
    trackingSince = DateTime.tryParse((j['trackingSince'] ?? '') as String) ?? dayOf(DateTime.now());
    _prefs?.remove('tutorialBackup');
    inTutorial = false;
  }

  /// Saves the user's real data, then loads the demo week for the tour.
  Future<void> startTutorial() async {
    if (inTutorial) return;
    await _prefs?.setString('tutorialBackup', _snapshot());
    inTutorial = true;
    loadDemo();
  }

  /// Puts the user's own data back.
  Future<void> endTutorial() async {
    final raw = _prefs?.getString('tutorialBackup');
    if (raw != null) _restoreBackup(raw);
    inTutorial = false;
    _commit();
  }
}
