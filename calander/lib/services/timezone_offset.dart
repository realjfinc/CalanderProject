/// A fixed-offset timezone label (e.g. "UTC-05:00") for the given moment,
/// in the format the extraction Cloud Function's timestamp parser (Luxon)
/// accepts as a zone specifier.
///
/// This is a deliberately simple stand-in for a real IANA zone name (which
/// would need a platform plugin to read on-device) — it captures the
/// current UTC offset, which is enough to disambiguate a time like "7pm"
/// extracted from a flyer for an event happening soon. It can be wrong for
/// an event far enough in the future to cross a DST boundary the device
/// hasn't crossed yet.
String currentTimezoneOffsetLabel([DateTime? now]) {
  final offset = (now ?? DateTime.now()).timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final absOffset = offset.abs();
  final hours = absOffset.inHours.toString().padLeft(2, '0');
  final minutes = (absOffset.inMinutes % 60).toString().padLeft(2, '0');
  return 'UTC$sign$hours:$minutes';
}
