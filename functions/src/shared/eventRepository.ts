import type { Firestore } from "firebase-admin/firestore";

import type { CanonicalEvent, CanonicalEventData } from "./canonicalEvent";

/**
 * Server-side counterpart to the Flutter client's `EventRepository`
 * interface. No realtime `watch` here -- a scheduled poll only ever needs
 * one snapshot per run -- but the write surface (add/update) is the same,
 * so `ingestProviderEvent` below can stay identical in shape to the
 * client's dedup/conflict utility.
 */
export interface EventRepository {
  listEvents(): Promise<CanonicalEvent[]>;
  addEvent(event: CanonicalEventData): Promise<string>;
  updateEvent(event: CanonicalEvent): Promise<void>;
}

function toFirestoreData(event: CanonicalEventData): FirebaseFirestore.DocumentData {
  return {
    title: event.title,
    location: event.location,
    start: new Date(event.start),
    end: new Date(event.end),
    source: event.source,
    sourceId: event.sourceId,
    sportsTeamIds: event.sportsTeamIds,
    status: event.status,
    tag: event.tag,
    importance: event.importance,
    notes: event.notes,
    attachments: event.attachments,
    repeat: event.repeat,
    reminders: event.reminders,
    conflictGroupId: event.conflictGroupId,
    conflictRole: event.conflictRole,
  };
}

function fromFirestoreDoc(id: string, data: FirebaseFirestore.DocumentData): CanonicalEvent {
  const start = data.start as FirebaseFirestore.Timestamp;
  const end = data.end as FirebaseFirestore.Timestamp;
  return {
    id,
    title: (data.title as string) ?? "",
    location: (data.location as string | null) ?? null,
    start: start.toDate().toISOString(),
    end: end.toDate().toISOString(),
    source: (data.source as CanonicalEvent["source"]) ?? "manual",
    sourceId: (data.sourceId as string | null) ?? null,
    sportsTeamIds: (data.sportsTeamIds as string[] | null) ?? null,
    status: data.status === "pendingConflict" ? "pendingConflict" : "active",
    tag: (data.tag as string | null) ?? null,
    importance: data.importance === "locked" ? "locked" : "flexible",
    notes: (data.notes as string | null) ?? null,
    attachments: (data.attachments as string[] | null) ?? null,
    repeat: (data.repeat as Record<string, unknown> | null) ?? null,
    reminders: (data.reminders as string[] | null) ?? null,
    conflictGroupId: (data.conflictGroupId as string | null) ?? null,
    conflictRole: (data.conflictRole as CanonicalEvent["conflictRole"]) ?? null,
  };
}

/** Firestore-backed `EventRepository`, scoped to `users/{uid}/events`. */
export class FirestoreEventRepository implements EventRepository {
  constructor(
    private readonly firestore: Firestore,
    private readonly uid: string,
  ) {}

  private get eventsRef() {
    return this.firestore.collection("users").doc(this.uid).collection("events");
  }

  async listEvents(): Promise<CanonicalEvent[]> {
    const snapshot = await this.eventsRef.get();
    return snapshot.docs.map((doc) => fromFirestoreDoc(doc.id, doc.data()));
  }

  async addEvent(event: CanonicalEventData): Promise<string> {
    const docRef = await this.eventsRef.add(toFirestoreData(event));
    return docRef.id;
  }

  async updateEvent(event: CanonicalEvent): Promise<void> {
    await this.eventsRef.doc(event.id).update(toFirestoreData(event));
  }
}
