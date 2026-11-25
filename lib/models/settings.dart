enum Personality { witty, calm, strict }

enum Tier { free, ultra }

class AppSettings {
  int workStartHour; // free time starts (24h clock)
  int workEndHour; // free time ends (max 24)
  double dailyCapacity; // realistic focused hours per day
  int blockMaxMinutes;
  int breakMinutes;
  bool voiceReplies;
  bool darkMode;
  int accentIndex; // index into C.accents
  Personality personality;
  Tier tier;
  String? voiceId; // ElevenLabs voice chosen in Ultra Pro
  String? voiceName;

  AppSettings({
    this.workStartHour = 17,
    this.workEndHour = 23,
    this.dailyCapacity = 5,
    this.blockMaxMinutes = 90,
    this.breakMinutes = 10,
    this.voiceReplies = true,
    this.darkMode = true,
    this.accentIndex = 0,
    this.personality = Personality.witty,
    this.tier = Tier.free,
    this.voiceId,
    this.voiceName,
  });

  bool get ultra => tier == Tier.ultra;

  Map<String, dynamic> toJson() => {
        'workStartHour': workStartHour,
        'workEndHour': workEndHour,
        'dailyCapacity': dailyCapacity,
        'blockMaxMinutes': blockMaxMinutes,
        'breakMinutes': breakMinutes,
        'voiceReplies': voiceReplies,
        'darkMode': darkMode,
        'accentIndex': accentIndex,
        'personality': personality.name,
        'tier': tier.name,
        'voiceId': voiceId,
        'voiceName': voiceName,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        workStartHour: ((j['workStartHour'] ?? 17) as num).toInt(),
        workEndHour: ((j['workEndHour'] ?? 23) as num).toInt(),
        dailyCapacity: ((j['dailyCapacity'] ?? 5) as num).toDouble(),
        blockMaxMinutes: ((j['blockMaxMinutes'] ?? 90) as num).toInt(),
        breakMinutes: ((j['breakMinutes'] ?? 10) as num).toInt(),
        voiceReplies: (j['voiceReplies'] ?? true) as bool,
        darkMode: (j['darkMode'] ?? true) as bool,
        accentIndex: ((j['accentIndex'] ?? 0) as num).toInt(),
        personality: Personality.values.firstWhere(
          (p) => p.name == j['personality'],
          orElse: () => Personality.witty,
        ),
        tier: j['tier'] == 'ultra' ? Tier.ultra : Tier.free,
        voiceId: j['voiceId'] as String?,
        voiceName: j['voiceName'] as String?,
      );
}
