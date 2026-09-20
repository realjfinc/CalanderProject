/**
 * Canonical event schema — the same hard contract as the Flutter client's
 * `lib/models/calendar_event.dart` (field names match exactly, so a
 * Firestore document looks identical regardless of whether it was written
 * by the app or by this Cloud Function). Timestamps are ISO-8601 UTC
 * strings; Firestore driver conversion to/from `Timestamp` happens at the
 * repository boundary, not here, so this stays a plain, easily-testable
 * data shape.
 */
export type EventSource =
  | "manual"
  | "upload"
  | "screenshot"
  | "google"
  | "outlook"
  | "icloud"
  | "sports";

export type EventStatus = "active" | "pendingConflict";

export type EventImportance = "locked" | "flexible";

export type ConflictRole = "original" | "new";

export interface CanonicalEventData {
  title: string;
  location: string | null;
  /** Always UTC, ISO-8601. Normalize at ingestion; never store local time. */
  start: string;
  end: string;
  source: EventSource;
  sourceId: string | null;
  /** Followed team ids represented by a sports event. */
  sportsTeamIds: string[] | null;
  status: EventStatus;
  /** Only direct user action or Step 5's routing logic may ever set this. */
  tag: string | null;
  importance: EventImportance;
  notes: string | null;
  attachments: string[] | null;
  repeat: Record<string, unknown> | null;
  reminders: string[] | null;
  conflictGroupId: string | null;
  conflictRole: ConflictRole | null;
}

export interface CanonicalEvent extends CanonicalEventData {
  id: string;
}

/** Defaults for fields a source adapter (this one included) never sets. */
export function newSourceEvent(
  fields: Pick<
    CanonicalEventData,
    "title" | "location" | "start" | "end" | "source" | "sourceId" | "notes"
  >,
): CanonicalEventData {
  return {
    ...fields,
    sportsTeamIds: null,
    status: "active",
    tag: null,
    importance: "flexible",
    attachments: null,
    repeat: null,
    reminders: null,
    conflictGroupId: null,
    conflictRole: null,
  };
}
