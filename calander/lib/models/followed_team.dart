/// A team the user follows for Sports Mode. `id` is the sports API's own
/// team id (used later as the basis for each game's `sourceId`).
class FollowedTeam {
  const FollowedTeam({required this.id, required this.name, required this.league, this.badgeUrl});

  final String id;
  final String name;
  final String league;
  final String? badgeUrl;

  factory FollowedTeam.fromMap(Map<String, dynamic> map) {
    return FollowedTeam(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Unknown team',
      league: map['league'] as String? ?? '',
      badgeUrl: map['badgeUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'league': league, 'badgeUrl': badgeUrl};
  }
}
