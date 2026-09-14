import 'package:flutter/material.dart';

/// Parses a `"#RRGGBB"` hex string (TheSportsDB's `strColour1` etc.) into a
/// [Color], or null for anything that isn't exactly that shape -- used to
/// tint a team's card with its own real brand color instead of one flat
/// app-wide accent.
Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  final match = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(hex);
  if (match == null) return null;
  return Color(int.parse('FF${match.group(1)}', radix: 16));
}

/// A short, human "when" label for a game's start time, most-specific
/// first -- the FotMob-style "Today" / "Tomorrow" / "in 5 days" a person
/// actually scans for, falling back to a full date once it's far enough
/// out that a relative count stops being useful at a glance.
String relativeGameLabel(DateTime start) {
  final now = DateTime.now();
  final startLocal = start.toLocal();
  final startDay = DateTime(startLocal.year, startLocal.month, startLocal.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = startDay.difference(today).inDays;

  if (days < 0) return 'Started';
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days < 7) return 'In $days days';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[startLocal.month - 1]} ${startLocal.day}';
}

/// A circular team badge: the real crest image once it loads, a softly
/// animated fade so it never just pops in, and a colored initial while
/// loading or if the team has no badge image at all.
class TeamBadge extends StatelessWidget {
  const TeamBadge({
    super.key,
    required this.name,
    this.badgeUrl,
    this.color,
    this.size = 44,
  });

  final String name;
  final String? badgeUrl;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );

    if (badgeUrl == null || badgeUrl!.isEmpty) return fallback;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          badgeUrl!,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              return AnimatedOpacity(
                opacity: 1,
                duration: const Duration(milliseconds: 250),
                child: child,
              );
            }
            return fallback;
          },
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      ),
    );
  }
}
