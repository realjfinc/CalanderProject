import '../models/event_tag.dart';

/// Default tags created for every new account.
const List<String> kDefaultTagNames = ['Work', 'Personal', 'School'];

/// Per-user tag storage. Implementations are responsible for scoping all
/// operations to the current user (e.g. `users/{uid}/tags`).
abstract class TagRepository {
  /// Streams the current user's tags, ordered by creation time.
  Stream<List<EventTag>> watchTags();

  /// Creates the default tag set (Work/Personal/School) for a new account.
  ///
  /// Safe to call on every app start: it is a no-op for any account that has
  /// already been initialized, so it will never resurrect a default tag the
  /// user deliberately deleted.
  Future<void> ensureDefaultTagsInitialized();

  /// Creates a new custom tag and returns it.
  Future<EventTag> addTag({required String name, required int colorValue});

  /// Updates an existing tag's name and/or color.
  Future<void> updateTag(String tagId, {String? name, int? colorValue});

  /// Deletes a tag. Does not touch events that currently reference it.
  Future<void> deleteTag(String tagId);
}
