import { initializeApp } from "firebase/app";
import { getAuth, onAuthStateChanged, signInWithEmailAndPassword, signOut } from "firebase/auth";
import { getFunctions, httpsCallable } from "firebase/functions";
import { getFirestore, collection, addDoc, Timestamp } from "firebase/firestore";
import { getStorage, ref, uploadString, getDownloadURL } from "firebase/storage";

import { firebaseConfig } from "./firebaseConfig.js";
import { splitDataUrl } from "./dataUrl.js";
import { currentTimezoneOffsetLabel } from "./timezoneOffset.js";
import { buildExtractionRequest, buildScreenshotEvent } from "./eventPayload.js";

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const functions = getFunctions(app);
const db = getFirestore(app);
const storage = getStorage(app);

const loginSection = document.getElementById("login-section");
const mainSection = document.getElementById("main-section");
const loginError = document.getElementById("login-error");
const statusText = document.getElementById("status-text");
const confirmForm = document.getElementById("confirm-form");

let lastScreenshotDataUrl = null;

onAuthStateChanged(auth, (user) => {
  loginSection.hidden = Boolean(user);
  mainSection.hidden = !user;
});

document.getElementById("sign-in-button").addEventListener("click", async () => {
  loginError.hidden = true;
  try {
    await signInWithEmailAndPassword(
      auth,
      document.getElementById("email-input").value,
      document.getElementById("password-input").value,
    );
  } catch (error) {
    loginError.textContent = error.message;
    loginError.hidden = false;
  }
});

document.getElementById("sign-out-button").addEventListener("click", () => signOut(auth));

document.getElementById("capture-button").addEventListener("click", async () => {
  statusText.textContent = "Capturing…";
  confirmForm.hidden = true;
  try {
    const dataUrl = await chrome.tabs.captureVisibleTab(undefined, { format: "png" });
    lastScreenshotDataUrl = dataUrl;
    const { mimeType, base64 } = splitDataUrl(dataUrl);

    statusText.textContent = "Extracting event…";
    const extract = httpsCallable(functions, "extractEvent");
    const request = buildExtractionRequest({
      base64,
      mimeType,
      timezone: currentTimezoneOffsetLabel(),
    });
    const result = await extract(request);

    fillConfirmForm(result.data);
    statusText.textContent = "";
    confirmForm.hidden = false;
  } catch (error) {
    statusText.textContent = `Could not extract an event: ${error.message}`;
  }
});

function fillConfirmForm(extracted) {
  document.getElementById("title-input").value = extracted.title ?? "";
  document.getElementById("location-input").value = extracted.location ?? "";
  document.getElementById("start-input").value = toLocalInputValue(extracted.startUtc);
  document.getElementById("end-input").value = toLocalInputValue(extracted.endUtc);
  document.getElementById("notes-input").value = extracted.notes ?? "";
}

function toLocalInputValue(isoUtc) {
  const date = new Date(isoUtc);
  const pad = (n) => String(n).padStart(2, "0");
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
    `T${pad(date.getHours())}:${pad(date.getMinutes())}`
  );
}

confirmForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    const user = auth.currentUser;
    if (!user) throw new Error("Not signed in.");

    let attachmentUrl = null;
    if (lastScreenshotDataUrl) {
      const fileName = `${Date.now()}-screenshot.png`;
      const storageRef = ref(storage, `users/${user.uid}/uploads/${fileName}`);
      await uploadString(storageRef, lastScreenshotDataUrl, "data_url");
      attachmentUrl = await getDownloadURL(storageRef);
    }

    const eventFields = buildScreenshotEvent({
      title: document.getElementById("title-input").value,
      location: document.getElementById("location-input").value,
      startUtc: new Date(document.getElementById("start-input").value).toISOString(),
      endUtc: new Date(document.getElementById("end-input").value).toISOString(),
      notes: document.getElementById("notes-input").value,
      attachmentUrl,
    });

    await addDoc(collection(db, "users", user.uid, "events"), {
      ...eventFields,
      start: Timestamp.fromDate(new Date(eventFields.start)),
      end: Timestamp.fromDate(new Date(eventFields.end)),
    });

    statusText.textContent = "Saved!";
    confirmForm.hidden = true;
    confirmForm.reset();
    lastScreenshotDataUrl = null;
  } catch (error) {
    statusText.textContent = `Could not save the event: ${error.message}`;
  }
});

document.getElementById("discard-button").addEventListener("click", () => {
  confirmForm.hidden = true;
  confirmForm.reset();
  lastScreenshotDataUrl = null;
  statusText.textContent = "";
});
