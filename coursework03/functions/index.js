/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");


// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({maxInstances: 10});

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

initializeApp();
const db = getFirestore();

exports.completeToday = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  if (request.data?.challengeId !== "today") {
    throw new HttpsError("invalid-argument", "Unknown challenge.");
  }
  const uid = request.auth.uid;
  const progressRef = db.doc(`users/${uid}/progress/today`);
  return db.runTransaction(async (transaction) => {
    const progress = await transaction.get(progressRef);
    if (progress.exists) {
      return {
        completed: true,
        points: progress.data().points,
        badgeId: progress.data().badgeId,
        alreadyCompleted: true,
      };
    }
    const reward = {
      completed: true,
      points: 10,
      badgeId: "first-quest",
      completedAt: FieldValue.serverTimestamp(),
    };
    transaction.set(progressRef, reward);
    return {
      completed: true,
      points: reward.points,
      badgeId: reward.badgeId,
      alreadyCompleted: false,
    };
  });
});

exports.askQuestCoach = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  const question = (request.data?.question ?? "").toString().trim();
  if (!question) {
    throw new HttpsError("invalid-argument", "Question is required.");
  }
  // api goes here?
  return { reply: "..." };
});
