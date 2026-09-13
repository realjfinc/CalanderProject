import '../models/tag_rule.dart';

/// Per-user tag-routing settings: `autoTagEnabled` and the ordered
/// `tagRules` list.
abstract class TagRoutingRepository {
  Stream<TagRoutingSettings> watchSettings();

  Future<void> updateSettings(TagRoutingSettings settings);
}
