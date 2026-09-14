/// A team the user follows for Sports Mode. `id` is the sports API's own
/// team id (used later as the basis for each game's `sourceId`).
class FollowedTeam {
  const FollowedTeam({
    required this.id,
    required this.name,
    required this.league,
    this.badgeUrl,
    this.accentColorHex,
  });

  final String id;
  final String name;
  final String league;
  final String? badgeUrl;

  /// The team's real primary brand color from TheSportsDB (e.g. `"#EF0107"`
  /// for Arsenal's red), used to give each team's card its own identity
  /// instead of one flat app color. Null for teams followed before this
  /// field existed, or when the API doesn't have one -- callers fall back
  /// to the app's own accent color in that case.
  final String? accentColorHex;

  factory FollowedTeam.fromMap(Map<String, dynamic> map) {
    return FollowedTeam(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Unknown team',
      league: map['league'] as String? ?? '',
      badgeUrl: map['badgeUrl'] as String?,
      accentColorHex: map['accentColorHex'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'league': league,
      'badgeUrl': badgeUrl,
      'accentColorHex': accentColorHex,
    };
  }
}
