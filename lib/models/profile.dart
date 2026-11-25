/// Local account stored on the phone. Google sign-in and cloud sync are a
/// planned update; until then the account never leaves the device.
class Profile {
  String name;
  String email;
  String passwordHash;
  String college;
  bool signedIn;
  final DateTime createdAt;

  Profile({
    required this.name,
    required this.email,
    required this.passwordHash,
    this.college = '',
    this.signedIn = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get firstName {
    final n = name.trim();
    if (n.isEmpty) return 'there';
    return n.split(RegExp(r'\s+')).first;
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'passwordHash': passwordHash,
        'college': college,
        'signedIn': signedIn,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: (j['name'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        passwordHash: (j['passwordHash'] ?? '') as String,
        college: (j['college'] ?? '') as String,
        signedIn: (j['signedIn'] ?? false) as bool,
        createdAt: DateTime.tryParse((j['createdAt'] ?? '') as String),
      );
}
