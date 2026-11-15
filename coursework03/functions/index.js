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

const {defineSecret} = require("firebase-functions/params");
const {GoogleGenerativeAI} = require("@google/generative-ai");

const geminiApiKey = defineSecret("GEMINI_API_KEY");
const getChallengeAndProgressTool = {
  functionDeclarations: [
    {
      name: "getChallengeAndProgress",
      description:
        "Reads today's challenge prompt and this learner's own progress. " +
        "Read-only: cannot modify data or grant rewards.",
      parameters: {type: "object", properties: {}},
    },
  ],
};

exports.askQuestCoach = onCall(
  {secrets: [geminiApiKey]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in first.");
    }
    const question = (request.data?.question ?? "").toString().trim();
    if (!question) {
      throw new HttpsError("invalid-argument", "Question is required.");
    }

    const uid = request.auth.uid;

    async function getChallengeAndProgress() {
      const [challengeSnap, progressSnap] = await Promise.all([
        db.doc("challenges/today").get(),
        db.doc(`users/${uid}/progress/today`).get(),
      ]);
      return {
        challenge: challengeSnap.data() ?? null,
        progress: progressSnap.data() ?? null,
      };
    }

    const genAI = new GoogleGenerativeAI(geminiApiKey.value());
    const model = genAI.getGenerativeModel({
      model: "gemini-3.8-flash",
      tools: [getChallengeAndProgressTool],
      systemInstruction:
        "You are a supportive quest coach. Use the supplied quest data to give one concise hint, not the complete answer. Never claim a reward was granted. You cannot write data; the learner decides whether to use the separate Complete button.",
    });

    const chat = model.startChat();
    let result = await chat.sendMessage(question);

    const call = result.response.functionCalls()?.[0];
    if (call?.name === "getChallengeAndProgress") {
      const toolResult = await getChallengeAndProgress();
      result = await chat.sendMessage([
        {
          functionResponse: {
            name: "getChallengeAndProgress",
            response: toolResult,
          },
        },
      ]);
    }

    const reply = result.response.text();
    return {reply};
  },
);
