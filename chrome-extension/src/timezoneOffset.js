/**
 * A fixed-offset timezone label (e.g. "UTC-05:00") in the format the
 * extraction Cloud Function's Luxon-based parser accepts as a zone
 * specifier. Mirrors `calander/lib/services/timezone_offset.dart` — same
 * deliberate simplification (current UTC offset, not a real IANA zone).
 */
export function currentTimezoneOffsetLabel(now = new Date()) {
  // JS's getTimezoneOffset() is minutes *behind* UTC (positive west of UTC),
  // the opposite sign convention from the "UTC+HH:MM" label we want.
  const offsetMinutes = -now.getTimezoneOffset();
  const sign = offsetMinutes < 0 ? "-" : "+";
  const abs = Math.abs(offsetMinutes);
  const hours = String(Math.floor(abs / 60)).padStart(2, "0");
  const minutes = String(abs % 60).padStart(2, "0");
  return `UTC${sign}${hours}:${minutes}`;
}
