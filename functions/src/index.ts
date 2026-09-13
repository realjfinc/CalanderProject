import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";

import { FirestoreEventRepository } from "./shared/eventRepository";
import { fetchUpcomingEventsRaw } from "./sports/theSportsDbClient";
import { pollUpcomingGames } from "./sports/pollUpcomingGames";

initializeApp();

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
