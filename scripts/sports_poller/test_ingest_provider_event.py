import pytest

from canonical_event import CanonicalEvent, new_source_event
from ingest_provider_event import ingest_provider_event


class FakeEventRepository:
    def __init__(self):
        self.events: list[CanonicalEvent] = []
        self._next_id = 1

    def list_events(self) -> list[CanonicalEvent]:
        return list(self.events)

    def add_event(self, event) -> str:
        event_id = f"id-{self._next_id}"
        self._next_id += 1
        self.events.append(CanonicalEvent(**vars(event), id=event_id))
        return event_id

    def update_event(self, event: CanonicalEvent) -> None:
        self.events = [event if e.id == event.id else e for e in self.events]


def _game(**overrides):
    fields = dict(
        title="Arsenal vs Chelsea",
        location="Emirates Stadium",
        start="2026-03-01T15:00:00.000Z",
        end="2026-03-01T18:00:00.000Z",
        source="sports",
        source_id="g1",
        notes="EPL",
    )
    fields.update(overrides)
    return new_source_event(**fields)


def test_a_genuinely_new_event_is_added_as_is():
    repository = FakeEventRepository()
    result = ingest_provider_event(repository=repository, incoming=_game(), current_events=[])

    assert result.title == "Arsenal vs Chelsea"
    assert result.tag is None
    assert result.status == "active"
    assert len(repository.events) == 1


def test_resyncing_the_same_source_and_source_id_updates_in_place_and_preserves_a_manual_tag():
    repository = FakeEventRepository()
    first = ingest_provider_event(repository=repository, incoming=_game(), current_events=[])

    # Simulate the user (or Step 5's routing) tagging the event.
    from dataclasses import replace

    tagged = replace(first, tag="Sports")
    repository.update_event(tagged)

    resynced = ingest_provider_event(
        repository=repository,
        incoming=_game(location="New Venue"),
        current_events=[tagged],
    )

    assert resynced.id == first.id
    assert resynced.tag == "Sports"
    assert resynced.location == "New Venue"
    assert len(repository.events) == 1


def test_a_similar_title_and_close_start_time_from_a_different_source_becomes_a_pending_conflict():
    repository = FakeEventRepository()
    existing = ingest_provider_event(
        repository=repository,
        incoming=new_source_event(
            title="Arsenal vs Chelsea",
            location=None,
            start="2026-03-01T15:00:00.000Z",
            end="2026-03-01T17:00:00.000Z",
            source="google",
            source_id="cal-1",
            notes=None,
        ),
        current_events=[],
    )

    result = ingest_provider_event(repository=repository, incoming=_game(), current_events=[existing])

    assert result.status == "pendingConflict"
    assert result.conflict_role == "new"
    assert result.conflict_group_id

    updated_original = next(e for e in repository.events if e.id == existing.id)
    assert updated_original.status == "pendingConflict"
    assert updated_original.conflict_role == "original"
    assert updated_original.conflict_group_id == result.conflict_group_id


def test_regression_resyncing_both_sides_of_a_conflict_repeatedly_never_loses_conflict_role():
    # Guards the exact class of bug the Dart/TS ports both guard against: an
    # update that omits conflictRole would silently default it away on
    # every resync, corrupting the conflict pair.
    repository = FakeEventRepository()
    original = ingest_provider_event(
        repository=repository,
        incoming=new_source_event(
            title="Arsenal vs Chelsea",
            location=None,
            start="2026-03-01T15:00:00.000Z",
            end="2026-03-01T17:00:00.000Z",
            source="google",
            source_id="cal-1",
            notes=None,
        ),
        current_events=[],
    )

    new_side = ingest_provider_event(
        repository=repository, incoming=_game(), current_events=[original]
    )

    for _ in range(3):
        original_now = next(e for e in repository.events if e.id == original.id)
        new_side = ingest_provider_event(
            repository=repository, incoming=_game(), current_events=[original_now, new_side]
        )

    final_original = next(e for e in repository.events if e.id == original.id)
    final_new = next(e for e in repository.events if e.id == new_side.id)
    assert final_original.conflict_role == "original"
    assert final_new.conflict_role == "new"
    assert final_original.conflict_group_id == final_new.conflict_group_id
    assert len(repository.events) == 2


def test_raises_if_an_incoming_event_already_carries_a_tag():
    from dataclasses import replace

    repository = FakeEventRepository()
    with pytest.raises(ValueError):
        ingest_provider_event(
            repository=repository, incoming=replace(_game(), tag="Sports"), current_events=[]
        )
