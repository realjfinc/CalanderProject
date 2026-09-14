import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions/v2";

import { extractEvent as runExtraction } from "./extraction/extractEvent";
import { AnthropicLlmClient } from "./extraction/llmClient";
import type { ExtractRequest } from "./extraction/types";
import { FirestoreEventRepository } from "./shared/eventRepository";
import { fetchUpcomingEventsRaw } from "./sports/theSportsDbClient";
import { pollUpcomingGames } from "./sports/pollUpcomingGames";
import { limitExtraction } from "./shared/rateLimiter";

initializeApp();

const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

/**
 * Callable Cloud Function: extracts structured event data from an uploaded
 * image, PDF, or link (Step 3). Returns the extracted fields for the
 * client's confirm-before-commit UI — never writes to Firestore itself.
 */
export const extractEvent = onCall({ secrets: [anthropicApiKey] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to extract an event.");
  }

  const data = request.data as ExtractRequest;
  if (!data || typeof data.type !== "string" || typeof data.timezone !== "string") {
    throw new HttpsError("invalid-argument", "Request must include a type and timezone.");
  }

  // Keep this outside the extraction catch so resource-exhausted reaches the UI.
  await limitExtraction(request.auth.uid);
  const llmClient = new AnthropicLlmClient(anthropicApiKey.value());
  try {
    return await runExtraction(data, llmClient);
  } catch (error) {
    throw new HttpsError("invalid-argument", (error as Error).message);
  }
});

/**
 * Step 7's scheduled polling function: every 6 hours, checks every user's
 * followed teams for upcoming games and ingests them through the same
 * shared dedup/conflict utility the client's manual "Sync Now" button
 * uses. Games are added with `source: "sports"`, `tag: null` -- only
 * direct user action or Step 5's routing logic ever assigns `tag`.
 */
export const pollSportsEvents = onSchedule("every 6 hours", async () => {
  const firestore = getFirestore();

  const result = await pollUpcomingGames({
    listUserIds: async () => {
      const snapshot = await firestore.collection("users").get();
      return snapshot.docs.map((doc) => doc.id);
    },
    listFollowedTeamIds: async (uid) => {
      const snapshot = await firestore
        .collection("users")
        .doc(uid)
        .collection("followedTeams")
        .get();
      return snapshot.docs.map((doc) => doc.id);
    },
    fetchUpcomingEventsRaw: (teamId) => fetchUpcomingEventsRaw(teamId),
    makeEventRepository: (uid) => new FirestoreEventRepository(firestore, uid),
  });

  logger.info("pollSportsEvents complete", result);
});
